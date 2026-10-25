# tailscale

The tailnet itself — the policy file (access rules, tags, hosts) and the OAuth
clients CI authenticates with — as OpenTofu, replacing configuration that used
to be clicked into the Tailscale admin console.

`SIGNOZ_ACCESS_TOKEN` and friends aside, this unit is the first one whose
"provider" is not a cloud account but an identity boundary: the policy file
decides which devices and tags may reach `10.0.0.99` and `10.0.0.200`, which is
to say it decides whether CI, the cluster and the operator can talk to each
other at all. That is why it is reviewed as a file in this repository and not as
a diff in a web console.

## Status

This unit owns the policy file (`tailscale_acl.this` -> `tailnet.hujson`). The
file was imported from the admin console verbatim, so the first apply after the
import was a no-op apart from the intended `tag:ci-plan` addition.

Trust credentials are **not** managed here. Two reasons, both learned the hard
way:

- A node may only ask for tags that match its credential's tag list exactly, so
  a credential per trust domain (`tag:ci` for apply, `tag:ci-plan` for plan) is
  the shape that works — and that is identity, not policy.
- Creating or updating an OAuth client through Terraform needs the management
  credential to hold `auth_keys`/`oauth_keys` itself, and the client secret ends
  up in state. Neither is worth it: the credential is created once in the console
  and rotated there.

So the split is: the policy file is reviewed in this repository, the credentials
that authenticate against it live in the admin console and in GitHub secrets.

## Credentials

A Tailscale trust credential, read by the provider from the environment:

| Variable | Purpose |
| --- | --- |
| `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET` | a trust credential scoped to `policy_file`, `devices:core:read` and `devices:posture_attributes` (the last two are required by `policy_file`). It needs no `auth_keys`, no `oauth_keys` and no tags: this unit writes policy, never credentials or nodes. |

Those two environment names are what the provider reads, so CI maps the
repository secrets into them:

```yaml
TAILSCALE_OAUTH_CLIENT_ID: ${{ secrets.TS_TF_OAUTH_CLIENT_ID }}
TAILSCALE_OAUTH_CLIENT_SECRET: ${{ secrets.TS_TF_OAUTH_SECRET }}
```

`TS_TF_*` is the management credential Terraform authenticates with; it is a
different credential from `TS_OAUTH_CLIENT_ID`/`TS_OAUTH_SECRET`, which mint
runner nodes during a plan or apply.
| `TAILSCALE_API_KEY` | alternative to the pair above, a personal API key — not recommended |

In CI these are repository secrets of the same names; locally, export them. The
generated `_provider.tf` deliberately contains no credential: a generate block is
rewritten on every run and would otherwise become a file waiting to be committed.

## First apply

This unit is new, so it has no state object yet, and a plan role cannot create
one: the role is scoped to object keys and holds no `s3:ListBucket`, which makes
S3 answer a missing key with `403` instead of `404`. Run the first
`terragrunt apply` from a workstation with the credential exported, and CI plans
every run after that. Same rule as adding any unit, recorded in `AGENTS.md`.

## Taking ownership of the policy file

The resource is `tailscale_acl`, which manages the **whole** policy file. Two of
its defaults are load-bearing here and must not be changed casually:

- `overwrite_existing_content = false` — an apply cannot replace the live policy
  until it has been imported, so a mistaken first run fails instead of clobbering
  the tailnet;
- `reset_acl_on_destroy = false` — destroying this unit must never restore
  Tailscale's allow-all default.

Order:

```bash
cd modules/tailscale

# 1. the live policy, verbatim, as the file this unit will manage
curl -sf -H "Authorization: Bearer ${TS_TOKEN}" \
  "https://api.tailscale.com/api/v2/tailnet/-/acl" | jq . > tailnet.hujson

# 2. state ownership of the file
terragrunt import tailscale_acl.this acl

# 3. the CI OAuth client, by client ID (``k...``); the secret is not returned by
#    the API and stays untouched by the import
terragrunt import tailscale_oauth_client.ci k...

# 4. review the plan: it should show only the intended edits
terragrunt plan
```

Only then should `acl.tf` swap the data source for the resource. The first plan
after the import is the review: importing an unchanged file must be a no-op.

## Once Terraform owns it

- `tailscale_tailnet_settings` with `acls_externally_managed_on = true` stops the
  admin console from editing the policy, so the file and the tailnet cannot
  drift. Recovery from a bad policy is then a code change (or a deliberate
  console override), not a click.
- `tag:ci-plan` (see #15) is added to `tagOwners` and to the CI OAuth client's
  tags here, which removes the manual console step that plan-job isolation
  otherwise needs.

## Avoid locking the tailnet

The policy file governs connectivity, not the control plane: an apply that
breaks `tag:ci` grants still reaches `api.tailscale.com`, but the cluster,
Cloudflared and CI lose their tailnet reachability. Two habits keep that
recoverable:

- read the plan's `grants`/`acls` diff, not just the resource count;
- keep the operator's own `group:admin` → `*:*` rule in the file, so a bad tag
  grant can be fixed by a human who is still connected.
