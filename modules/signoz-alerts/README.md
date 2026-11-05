# signoz-alerts

Sandbox + Strata detection rules for SigNoz, managed with Terragrunt + OpenTofu
using the official [`SignNoz/signoz`](https://registry.terraform.io/providers/SigNoz/signoz/latest)
provider (v0.1.4).

This is a sibling of `signoz-dashboards`, not an extra unit inside it: alert
rules and dashboards have separate lifecycles, and a broken alert should not
block a dashboard apply (or the reverse).

## Rules

| Resource | Signal | Backing series / source |
| --- | --- | --- |
| `sandbox_pod_restarted` | Sandbox container restarted | `k8s.container.restarts` via kubeletstats |
| `strata_scrape_down` | Strata `/metrics` scrape returned `up=0` | `up` builder query filtered by `service.name=strata` |
| `sandbox_telemetry_not_ready` | The collector pod is not Ready | `k8s.container.ready` in `sandbox-telemetry` |
| `sandbox_conntrack_pressure` | Guest conntrack table > 80% | `node_nf_conntrack_entries*` from node-exporter |
| `squid_denied_egress` | Sandbox tried to egress through the deny-all proxy | Squid container log `TCP_DENIED` |

The rules fire in SigNoz's alert history even without a notification channel.
Create a channel in SigNoz and add its display name to a rule's
`channels` list when one exists; this module intentionally does not invent a
webhook endpoint.

## Why some issue #74 signals are not here

- **Strata 401 rate** — Strata exposes no auth-failure counter, and it does not
  log rejected requests. A rule on a series that does not exist would be worse
  than no rule. Upstream instrumentation or an engine-image wrapper is the
  prerequisite.
- **gVisor `runsc` OOM/start failures** — the debug logs are on the guest volume
  `/var/lib/runsc-logs` and are not ingested yet. The pod-restart rule covers the
  observable symptom in the meantime.
- **Sustained sandbox egress outside the proxy path** — the guest nftables filter
  drops silently. The conntrack rule is the available saturation proxy.

## Configuration

The unit reads the endpoint directly (`find_in_parent_folders` does not look in the current directory, so there is no same-directory `common.hcl`). The apply generates `_provider.tf`:

- `SIGNOZ_ENDPOINT` (default `https://signoz.cowlab.org`)
- `SIGNOZ_ACCESS_TOKEN` — read by the provider from the environment, never
  written to `_provider.tf` or state.

See the API-key runbook in the cluster repo:
`homelab-cluster/docs/operator-guide/runbooks/signoz-dashboard-api-key.md`.

## Local validation

The unit is discovered by `deploy.yaml` automatically (any
`modules/*/terragrunt.hcl`). Without AWS credentials, validate the schema
directly:

```bash
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
```
