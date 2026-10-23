# homelab-terraform

Terragrunt + OpenTofu root for the `cowlab.org` homelab. Every directory under `modules/`
is an independent unit with its own S3 state key, so units apply independently.

`.github/workflows/deploy.yaml` is the only CI entry point: on a pull request it runs the
formatters and a backend-less validate with no credentials; on a push to a branch it plans
every unit and comments the diff on that branch's pull request; on `main` it then applies
behind the `deploy` GitHub environment and runs a telemetry smoke query.

## Units

| Unit | Manages |
| --- | --- |
| `modules/cloudflare/` | The `cowlab.org` zone and its DNS records, a Cloudflare tunnel with an Access application, and Google as a Zero Trust identity provider. |
| `modules/argocd-install/` | ArgoCD: namespace, Helm release, and the OIDC client secret for its SSO configuration. |
| `modules/argocd-configure/` | The ArgoCD `bootstrap` Application that hands off to `homelab-cluster`. Depends on `argocd-install`. |
| `modules/s3-backups/` | The Longhorn backup bucket and the scoped IAM user and policy that writes to it. |
| `modules/signoz-dashboards/{homelab-overview,network-speeds,pi5-thermal}/` | One SigNoz dashboard each. See [`modules/signoz-dashboards/README.md`](modules/signoz-dashboards/README.md). |

`bootstrap/` is plain OpenTofu rather than Terragrunt, and is applied by hand once before
any unit: it creates the S3 state bucket and the GitHub Actions OIDC role that everything
else assumes. CI never touches it.

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
| `ALLOWED_EMAILS` | `cloudflare` — comma-separated |
| `SIGNOZ_ENDPOINT`, `SIGNOZ_ACCESS_TOKEN` | `signoz-dashboards` |
| AWS credentials or OIDC role | S3 remote state, `s3-backups` |
| `KUBECONFIG` | `argocd-*` only (base64-encoded in CI) |

In CI these come from GitHub Actions secrets and variables. Locally, export them in your
shell.

CI holds no long-lived AWS keys: the plan and apply jobs assume roles through GitHub OIDC.
The plan role is assumable only by push runs on a branch of this repository, so pull-request
runs — which cannot be distinguished from fork runs by their OIDC subject — get no AWS
credentials at all.

## Layout

```
root.hcl                       # shared Terragrunt root: OpenTofu binary + S3 remote state
common-inputs.yaml             # shared values read by the units
bootstrap/                     # one-time: state bucket + GitHub OIDC role
modules/terragrunt.hcl         # include-only stub that points units at root.hcl
modules/<unit>/                # one state key per unit
scripts/signoz-dashboard-smoke.sh
.github/workflows/deploy.yaml  # plan on PR, apply on main, then smoke query
```

## Generated files

Terragrunt rewrites `modules/**/_backend.tf` and `modules/**/_provider.tf` on every run
(`if_exists = "overwrite_terragrunt"`), so hand edits are lost. They are committed so a
cold checkout has a usable OpenTofu configuration, and regenerating them should be a no-op
in `git diff`.

[`AGENTS.md`](AGENTS.md) carries the fuller operating guidance, boundaries, and glossary
for coding agents.
