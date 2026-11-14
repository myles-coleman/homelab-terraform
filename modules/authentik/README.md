# modules/authentik

Declarative Authentik configuration: groups, forward-auth proxy providers, the
applications that use them, and the Traefik outpost. It does **not** deploy
Authentik — the server, Postgres, and Redis come from `manifests/cluster/authentik/`
in `myles-coleman/homelab-cluster`, and this unit configures the running instance
over its API.

## Authorization model

| Object | Purpose |
|---|---|
| `authentik_group` | group per `var.groups` key |
| `authentik_provider_proxy` | one proxy provider per application, `forward_single` by default |
| `authentik_application` | the app itself; no `group` field, so it is not auto-published to anyone |
| `authentik_policy_binding` | one per (application, group) pair — this is what grants access |
| `authentik_outpost` | the proxy outpost the Traefik forwardAuth middleware calls |

An application with an empty `groups` list gets **no** policy binding, so
`policy_engine_mode = "any"` admits nobody. Adding an app to this file does not
expose it: the app's Traefik `IngressRoute` must also carry the `authentik`
middleware, and the Cloudflare tunnel must route its hostname.

## Prerequisites, in order

1. **Authentik is running and reachable.** This unit's provider talks to
   `authentik_url` over the tailnet; a plan from a GitHub runner resolves
   `authentik.cowlab.org` to `10.0.0.99` and needs the tailnet node the plan job
   already brings up.
2. **`AUTHENTIK_TOKEN` exists** as a GitHub Actions secret. Create an API token in
   Authentik (Directory → Tokens, or a dedicated service account) and store it.
   The provider reads the environment variable itself, so the token never enters
   `_provider.tf` or Terraform state.
3. **The unit is registered with bootstrap.** Add `modules/authentik` to
   `local.plan_units` in `bootstrap/oidc.tf`, then apply `bootstrap/` by hand so
   the `terraform-plan-authentik` role exists. Without it the plan fails to
   assume a role.
4. **First apply runs locally.** Plan roles are scoped to object keys and hold no
   `s3:ListBucket`; S3 answers a missing key with `403`, not `404`, which surfaces
   as `Error refreshing state: HeadObject ... Forbidden`. Run the first
   `terragrunt apply` from a workstation with the token exported, then CI takes
   over from the second run.

## Workflow

```sh
export AUTHENTIK_TOKEN=...        # never commit this
cd modules/authentik
terragrunt init -backend=false && tofu init -backend=false && tofu validate
terragrunt plan
terragrunt apply                  # local first apply only
```

After that, CI plans every branch push and applies from `main`.

## Adding an application

1. Add an entry to `applications` in `terragrunt.hcl` with `external_host` and the
   `groups` allowed to reach it.
2. Declare any new group under `groups`; a reference to an undeclared group fails
   the `check` block in `policies.tf`.
3. Add the `authentik` forwardAuth middleware to that app's `IngressRoute` in the
   cluster repo, and route the hostname through the tunnel.
4. Outpost configuration is derived: the `authentik_outpost` resource rebuilds its
   `protocol_providers` list from every provider, so no manual outpost edit is
   needed.

## Related

- Server and outpost deployment: `homelab-cluster/manifests/cluster/authentik/`
- Traefik middleware: `homelab-cluster/manifests/cluster/traefik/middleware-authentik.yaml`
