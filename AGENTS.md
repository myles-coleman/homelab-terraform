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
modules/tailscale/             # tailnet policy file + CI OAuth clients (has its own README)
scripts/                       # signoz-dashboard-smoke.sh
.github/workflows/deploy.yaml  # format, validate on PR, plan on push, apply on main
.github/workflows/secrets.yaml # gitleaks gate over the full history
```

Each directory under `modules/` is its own unit with its own state key
(`${path_relative_to_include()}/terraform.tfstate`), so units apply independently and one
bad unit does not block the rest.

`bootstrap/` is applied by hand, once, before any unit — it creates the state bucket, the
GitHub OIDC provider, one read-only plan role per unit, and the administrative apply role that
everything else assumes. CI deliberately never applies it: every push plans it with
`terraform-plan-bootstrap` and comments the diff on the branch's pull request, and a human runs
`tofu apply` from the reviewed plan.

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
- **`environment: deploy`** — the GitHub environment on the apply job. It carries one
  protection rule, a branch policy limited to `main`, and **no required reviewers**: this
  repository's plan does not support that rule, and enabling it is an account upgrade, not a
  repository change. So it bounds *where* an apply can come from; it is not an approval.
  The plan comment on the pull request is the review, and `main` applies automatically once
  it plans.
- **tailnet policy** — the Tailscale policy file (grants, `tagOwners`, hosts) in
  `modules/tailscale/tailnet.hujson`, imported from the admin console and now authoritative:
  a change to tailnet access is a diff here, not a click there. Trust credentials stay in the
  console — a node may only ask for exactly its credential's tags, so there is one credential
  per trust domain and Terraform does not manage them. See that unit's README for the two
  `tailscale_acl` defaults that stop a mistaken apply from clobbering it.
- **bootstrap project** — the ArgoCD `AppProject` the root Application runs under
  (`modules/argocd-configure/bootstrap.tf`): source `myles-coleman/homelab-cluster` only,
  destination `argocd` only, `Application` objects only, and nothing cluster-scoped. It bounds
  what the synced `manifests/bootstrap` path may create. The 46 child Applications it creates
  still run under that repository's `default` project, which this tree cannot change.
- **plan trust anchor** — the plan roles trust only the `ref:refs/heads/*` OIDC subject, which
  only a push to a branch of this repository can present; `pull_request` runs get no AWS
  credentials at all.
- **plan role** — one per unit, `terraform-plan-<plan_role>`, so a plan can read only its own
  unit's state prefix and write only that unit's `*.tflock`. `AWS_PLAN_ROLE_ARN` is the family
  prefix `arn:aws:iam::<account>:role/terraform-plan`; the rest, `plan_role`, is the unit path
  with `/` flattened to `-`, computed by the discovery job in `deploy.yaml`. The roles
  themselves are declared in `bootstrap/oidc.tf`'s `local.plan_units`, not in a repository
  variable.
- **discovery job** — `units` in `deploy.yaml`. It lists `modules/*/terragrunt.hcl` from
  `git ls-files` and feeds the validate and plan matrices, so neither has a hand-written unit
  list. Adding a unit directory is enough for CI to validate and plan it.
- **bootstrap plan** — `plan-bootstrap` in `deploy.yaml`, plus the `bootstrap` job that
  validates and formats the directory on every run. The trust anchor is planned with
  `terraform-plan-bootstrap`, which reads `bootstrap/terraform.tfstate` and the
  `terraform-*` roles and policies and writes only that state's lock. It holds no unit
  credentials and no tailnet node. Applying `bootstrap/` is still a hand-run step.

## Boundaries

### Always

- Use `tofu`, not `terraform`: `root.hcl` sets `terraform_binary = "tofu"` and CI runs OpenTofu.
- Run unit-scoped commands from that unit's directory; run repo-wide commands from the
  repository root with `--all`.
- Open a pull request for changes under `modules/`. CI validates every unit on the PR (no
  credentials), plans every unit on each branch push and comments the diff on that branch's
  pull request; only `main` reaches apply. The unit list comes from the discovery job, so
  neither matrix in `deploy.yaml` lists modules by hand.
- Keep the formatters clean: `tofu fmt -check -recursive` (enforced by CI) and
  `terragrunt hcl format --check` (enforced by the `terragrunt_fmt` pre-commit hook).
- Keep the infrastructure arm64-compatible: the cluster is 4x Raspberry Pi 5.

### Ask first

- Changing `root.hcl`, or any `_backend.tf` state-backend configuration. Altering the bucket,
  key pattern, or region can orphan or split state.
- Adding a unit. A directory with a `terragrunt.hcl` and a non-colliding state key is picked up
  by the discovery job automatically, but it also needs an entry in `local.plan_units` in
  `bootstrap/oidc.tf` and a `bootstrap/` apply by hand: until its plan role exists, its plan
  fails to assume anything. Its state object also has to exist before CI can plan it — plan
  roles are scoped to object keys and hold no `s3:ListBucket`, and S3 answers a *missing* key
  with `403 Forbidden` rather than `404` for a caller in that position, which surfaces as
  `Error refreshing state: HeadObject ... Forbidden` from `tofu init`. So the first
  `terragrunt apply` for a new unit runs locally, and CI takes over from the second run.
- Replacing the state bucket or the GitHub OIDC role in `bootstrap/`. Any change there gets a
  plan on the branch's pull request; apply it by hand, from that plan, before merging anything
  that depends on it.
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
- Never treat the `deploy` environment as an approval step. It has no required reviewers, so
  merging to `main` *is* the decision to apply, and the plan comment on the pull request is
  the only thing that will ever ask you to look. Read it before you merge; nothing asks again.

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
