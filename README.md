# homelab-terraform

Terragrunt + OpenTofu root for the `cowlab.org` homelab. Every directory under `modules/`
is an independent unit with its own S3 state key, so units apply independently.

`.github/workflows/deploy.yaml` is the CI entry point for the configuration: on a pull
request it runs the formatters and a backend-less validate with no credentials; on a push to a
branch it plans every unit and comments the diff on that branch's pull request; on `main` it
then applies behind the `deploy` GitHub environment and runs a telemetry smoke query.
`.github/workflows/secrets.yaml` is the other one: it scans the full history with gitleaks on
every push and pull request, with no path filter, so a token pasted into a document cannot
slip past it.

The unit list in CI is discovered, not hand-written: the `units` job lists
`modules/*/terragrunt.hcl` with `git ls-files` and feeds both the validate and plan matrices,
so a new unit needs no workflow edit.

## Units

| Unit | Manages |
| --- | --- |
| `modules/cloudflare/` | The `cowlab.org` zone and its DNS records, a Cloudflare tunnel with an Access application, and Google as a Zero Trust identity provider. |
| `modules/argocd-install/` | ArgoCD: namespace, Helm release, and the OIDC client secret for its SSO configuration. |
| `modules/argocd-configure/` | The ArgoCD `bootstrap` Application that hands off to `homelab-cluster`. Depends on `argocd-install`. |
| `modules/s3-backups/` | The Longhorn backup bucket and the scoped IAM user and policy that writes to it. |
| `modules/signoz-dashboards/{homelab-overview,network-speeds,pi5-thermal}/` | One SigNoz dashboard each. See [`modules/signoz-dashboards/README.md`](modules/signoz-dashboards/README.md). |

`bootstrap/` is plain OpenTofu rather than Terragrunt, and is applied by hand once before
any unit: it creates the S3 state bucket, the GitHub OIDC provider, one read-only plan role
per unit, and the administrative apply role that everything else assumes. CI never touches it.

## Requirements

- OpenTofu 1.11.x and Terragrunt 0.97.x, the versions pinned in
  `.github/workflows/deploy.yaml`.
- AWS credentials able to read the `myles-homelab-tfstate` bucket and assume the Terraform
  role.
- A Tailscale connection. The endpoints the units use are private: `10.0.0.99` (MetalLB)
  and `10.0.0.200` (kube-vip, the Kubernetes API). Public `*.cowlab.org` names resolve to
  `10.0.0.99`.

## Usage

Unit-scoped commands run from the unit directory:

```bash
cd modules/cloudflare
terragrunt plan -out=tfplan.tfplan
terragrunt apply
```

The `--all` forms run from the repository root and fan out to every unit:

```bash
terragrunt validate -all
terragrunt apply --all --non-interactive
```

Formatting is enforced by CI (`tofu fmt -check -recursive`) and by a pre-commit hook
(`terragrunt hcl format --check`):

```bash
pre-commit install
pre-commit run --all-files
```

The same hooks run a gitleaks secret scan on staged files, so `gitleaks` has to be on `PATH`
(`nix shell nixpkgs#gitleaks`). CI does not depend on it — `.github/workflows/secrets.yaml`
installs its own pinned release and scans the whole history.

Unit-level schema validation works without AWS credentials by stopping after
`terragrunt init -backend=false`; see
[`modules/signoz-dashboards/README.md`](modules/signoz-dashboards/README.md) for the
sequence.

## Credentials

Units read secrets only from the environment via `get_env(...)`; nothing is read from a
committed file.

| Variable | Used by |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | `cloudflare` |
| `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` | `cloudflare` |
| `ALLOWED_EMAILS` | `cloudflare` — comma-separated; a repository secret, and an empty or malformed list fails the plan |
| `SIGNOZ_ENDPOINT`, `SIGNOZ_ACCESS_TOKEN` | `signoz-dashboards` |
| AWS credentials or OIDC role | S3 remote state, `s3-backups` |
| `KUBECONFIG` | `argocd-*` only (base64-encoded in CI) |

In CI these come from GitHub Actions secrets and variables. Locally, export them in your
shell.

`CLOUDFLARE_API_TOKEN` and `SIGNOZ_ACCESS_TOKEN` are never written into a generated file:
their providers read them from the environment, and the generate blocks interpolate only
non-secret values.

CI holds no long-lived AWS keys: the plan and apply jobs assume roles through GitHub OIDC.
There is one plan role per unit (`terraform-plan-<unit slug>`), each able to read only its own
unit's state prefix and write only that unit's `*.tflock`, so planning one unit cannot read
another's state. They are assumable only by push runs on a branch of this repository, so
pull-request runs — which cannot be distinguished from fork runs by their OIDC subject — get
no AWS credentials at all.

## Layout

```
root.hcl                       # shared Terragrunt root: OpenTofu binary + S3 remote state
common-inputs.yaml             # shared values read by the units
bootstrap/                     # one-time: state bucket, OIDC provider, per-unit plan roles
modules/terragrunt.hcl         # include-only stub that points units at root.hcl
modules/<unit>/                # one state key per unit
scripts/signoz-dashboard-smoke.sh
.github/workflows/deploy.yaml  # discovery, PR validate, plan, apply, smoke
.github/workflows/secrets.yaml # gitleaks over the full history, every push and PR
```

## Generated files

Terragrunt rewrites `modules/**/_backend.tf` and `modules/**/_provider.tf` on every run
(`if_exists = "overwrite_terragrunt"`), so hand edits are lost. They are build output and are
gitignored rather than committed: Terragrunt generates them before OpenTofu runs, into the
unit directory on pre-1.0 releases and into `.terragrunt-cache/` from 1.0 on. A `git diff`
after a run is therefore always empty, and a non-empty one means a generated file was
force-added. The generate blocks never interpolate a credential, so nothing that depends on
the environment can reach the tree.

[`AGENTS.md`](AGENTS.md) carries the fuller operating guidance, boundaries, and glossary
for coding agents.
