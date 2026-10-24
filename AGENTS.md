# AGENTS.md

Guidance for AI coding agents working in `homelab-terraform` — the Terragrunt + OpenTofu
root that manages homelab infrastructure for `cowlab.org`.

## Layout

```
root.hcl                       # shared Terragrunt root: OpenTofu binary + S3 remote state
common-inputs.yaml             # shared inputs read by every unit
bootstrap/                     # plain Terraform, not Terragrunt: state bucket, OIDC provider, roles
modules/terragrunt.hcl         # include-only stub; every unit reaches root.hcl through it
modules/cloudflare/            # DNS records, zone, tunnel, Access
modules/argocd-install/        # ArgoCD Helm install
modules/argocd-configure/      # ArgoCD bootstrap configuration
modules/s3-backups/            # backup bucket + lifecycle policy
modules/signoz-dashboards/     # declarative SigNoz dashboards (has its own README)
scripts/                       # signoz-dashboard-smoke.sh
.github/workflows/deploy.yaml  # format, validate on PR, plan on push, apply on main
.github/workflows/secrets.yaml # gitleaks gate over the full history
```

Each directory under `modules/` is its own unit with its own state key
(`${path_relative_to_include()}/terraform.tfstate`), so units apply independently and one
bad unit does not block the rest.

`bootstrap/` is applied by hand, once, before any unit — it creates the state bucket, the
GitHub OIDC provider, one read-only plan role per unit, and the administrative apply role that
everything else assumes. CI deliberately never touches it.

## Commands

<!-- generated:begin id=commands -->
Toolchain: OpenTofu 1.11.x and Terragrunt 0.97.x, as pinned in .github/workflows/deploy.yaml.

- Validate a unit: `cd modules/<unit> && terragrunt validate`
- Plan a unit: `cd modules/<unit> && terragrunt plan -out=tfplan.tfplan`
- Show a saved plan: `cd modules/<unit> && terragrunt show -json tfplan.tfplan`
- Apply a unit: `cd modules/<unit> && terragrunt apply`
- Validate every unit: `terragrunt validate -all`
- Apply every unit: `terragrunt apply --all --non-interactive`
- Check OpenTofu formatting: `tofu fmt -check -recursive`
- Check HCL formatting: `terragrunt hcl format --check`
- Validate with no AWS credentials: `terragrunt init -backend=false && tofu init -backend=false && tofu validate`
- Post-deploy telemetry check: `./scripts/signoz-dashboard-smoke.sh`
- Install the git hooks: `pre-commit install`
- Run every git hook: `pre-commit run --all-files`
<!-- generated:end id=commands -->

Unit-scoped commands run from that unit's directory; the `--all` forms run from the
repository root. `modules/signoz-dashboards/README.md` and
`scripts/signoz-dashboard-smoke.sh` document the fuller sequences and the environment
variables they need.

## Domain Glossary

- **unit** — a directory with a `terragrunt.hcl` under `modules/`, owning exactly one state key.
- **`root.hcl`** — the only place the OpenTofu binary and the S3 remote state are configured.
- **generated file** — `_backend.tf` / `_provider.tf`, rewritten by Terragrunt on every run
  and gitignored: it is build output, not source.
- **`--all`** — Terragrunt flag that fans a command out to every descendant unit.
- **`environment: deploy`** — the GitHub environment gating the apply job; applying to `main`
  goes through it, not through a local run.
- **plan trust anchor** — the plan roles trust only the `ref:refs/heads/*` OIDC subject, which
  only a push to a branch of this repository can present; `pull_request` runs get no AWS
  credentials at all.
- **plan role** — one per unit, `terraform-plan-<plan_role>`, so a plan can read only its own
  unit's state prefix and write only that unit's `*.tflock`. `AWS_PLAN_ROLE_ARN` is the family
  prefix `arn:aws:iam::<account>:role/terraform-plan`; the plan matrix in `deploy.yaml` carries
  the rest as `plan_role`, the unit path with `/` flattened to `-`. The roles themselves are
  declared in `bootstrap/oidc.tf`'s `local.plan_units`, not in a repository variable.

## Boundaries

### Always

- Use `tofu`, not `terraform`: `root.hcl` sets `terraform_binary = "tofu"` and CI runs OpenTofu.
- Run unit-scoped commands from that unit's directory; run repo-wide commands from the
  repository root with `--all`.
- Open a pull request for changes under `modules/`. CI validates every module on the PR (no
  credentials), plans every module on each branch push and comments the diff on that branch's
  pull request; only `main` reaches apply.
- Keep the formatters clean: `tofu fmt -check -recursive` (enforced by CI) and
  `terragrunt hcl format --check` (enforced by the `terragrunt_fmt` pre-commit hook).
- Keep the infrastructure arm64-compatible: the cluster is 4x Raspberry Pi 5.

### Ask first

- Changing `root.hcl`, or any `_backend.tf` state-backend configuration. Altering the bucket,
  key pattern, or region can orphan or split state.
- Adding a unit. It needs a `terragrunt.hcl`, a non-colliding state key, an entry in both
  the `validate` and `plan` matrices in `deploy.yaml`, and an entry in `local.plan_units` in
  `bootstrap/oidc.tf` — then `bootstrap/` has to be applied again by hand, because the unit
  has no plan role until it is.
- Replacing the state bucket or the GitHub OIDC role in `bootstrap/`.
- Anything that moves the `10.0.0.99` load-balancer IP or the `argocd.cowlab.org`,
  `signoz.cowlab.org`, and `dex.cowlab.org` hostnames — the cluster repo depends on them.

### Never

- Never hand-edit `_backend.tf` or `_provider.tf`. Terragrunt regenerates them, so the edit is
  silently lost.
- Never commit a `.tfstate`, a `tfplan.tfplan`, a `.terraform/` directory, or a generated
  `_backend.tf` / `_provider.tf`; `.gitignore` covers them all.
- Never hardcode a secret, token, or kubeconfig in HCL. Unit inputs come from environment
  variables or GitHub Actions secrets.
- Never interpolate `get_env(...)` into a `generate` block. The generating block is written to
  disk on every run, so a credential placed there is a file waiting to be committed — providers
  read their tokens from the environment themselves (`CLOUDFLARE_API_TOKEN`,
  `SIGNOZ_ACCESS_TOKEN`).
- Never run `apply` or `destroy` against `main` outside CI, and never `apply --all` by hand.
- Never let a `pull_request` run hold AWS credentials. Its OIDC subject is
  `repo:<owner>/<repo>:pull_request` whether the head branch is in this repository or a fork,
  so it cannot express "same repository only"; the plan role trusts `ref:refs/heads/*` instead.
- Never bypass the `deploy` environment's approval to force an apply.

## Generated / Do-Not-Touch Paths

Terragrunt writes these on every run, and the generating blocks use
`if_exists = "overwrite_terragrunt"`, so manual edits are disposable:

- `modules/**/_backend.tf` — generated from the `remote_state` block in `root.hcl`.
- `modules/**/_provider.tf` — generated from each unit's `generate "provider"` block.
- `.terragrunt-cache/`, `.terraform/` — ignored entirely; never edit or commit them.

None of them are tracked. Nothing under `modules/` needs them in a cold checkout: Terragrunt
writes them before it invokes OpenTofu, into the unit directory on pre-1.0 releases and into
`.terragrunt-cache/` from 1.0 on. They were committed once, which is why a `git diff` after a
run used to be meaningful; now it must be empty, and a non-empty one means someone force-added
a generated file. Change the generating block and the next run produces the new file.
`bootstrap/_backend.tf` is the exception: it is hand-written plain OpenTofu, not generated.

## Secret Handling

- Configuration reads secrets only through `get_env(...)`: `CLOUDFLARE_API_TOKEN`,
  `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `ALLOWED_EMAILS`,
  `SIGNOZ_ENDPOINT`, `SIGNOZ_ACCESS_TOKEN`, and `KUBECONFIG` (base64, `argocd-*` units only).
- In CI these come from GitHub Actions secrets and variables; locally, export them in the
  shell. Never write a value into a `.tf`, `.hcl`, or `.yaml` file.
- `ALLOWED_EMAILS` is a repository **secret**, not a variable, and it is the only input to the
  Cloudflare Access allow policy. `modules/cloudflare/_variables.tf` rejects an empty or
  malformed list at plan time, so deleting the secret fails the plan instead of applying a
  policy that admits nobody — do not relax that validation to make a plan pass.
- `SIGNOZ_ACCESS_TOKEN` and `CLOUDFLARE_API_TOKEN` are read by their providers directly from
  the environment, so they stay out of `_provider.tf` and Terraform state. Keep it that way:
  the generated provider blocks are `provider "cloudflare" {}` and
  `provider "signoz" { endpoint = ... }`, with no credential line.
- `gitleaks` is the gate that matches credential shapes: as the `gitleaks-system` pre-commit
  hook (`gitleaks` must be on PATH) and over the full history in
  `.github/workflows/secrets.yaml`, which has no `paths` filter on purpose. `detect-private-key`
  also runs, and `.gitignore` covers `.env`. If a new secret is needed, add it as an Actions
  secret and reference it from the `deploy.yaml` env block — not from a committed file.
