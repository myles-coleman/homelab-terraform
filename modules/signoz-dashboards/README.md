# signoz-dashboards

Declarative SigNoz dashboards managed with Terragrunt + OpenTofu using the
official [`SignNoz/signoz`](https://registry.terraform.io/providers/SigNoz/signoz/latest)
provider (v0.1.4).

## Units

Each dashboard is its own Terragrunt unit with its own state key, so one invalid
dashboard cannot block the others:

| Unit | Dashboard |
| --- | --- |
| `homelab-overview/` | Homelab Overview — cluster/node triage surface |
| `network-speeds/` | Network Speeds — internet speed tests + node/pod throughput |
| `pi5-thermal/` | Pi 5 Thermal — per-node temperature, CPU frequency, load |
| `sandbox-runtime/` | Sandbox Runtime — pod and guest-node health, conntrack pressure, Squid denials |
| `strata-endpoint/` | Strata Endpoint — GPU, Strata engine, vLLM latency and cache |
| `agent-traces/` | Agent Traces — span volume/latency, uncaught errors, correlated logs |

## Configuration

The SigNoz provider is HTTP-based, so this module deviates from the
kubeconfig-based modules. `common.hcl` supplies the endpoint, and each unit
generates `_provider.tf` from it:

- `SIGNOZ_ENDPOINT` (default `https://signoz.cowlab.org`)
- `SIGNOZ_ACCESS_TOKEN` — read by the provider directly from the environment, so
  it is never written into `_provider.tf` or Terraform state (supplied by GitHub
  Actions secrets or the local shell)

See the API key runbook in the cluster repo:
<https://github.com/myles-coleman/homelab-cluster/blob/main/docs/operator-guide/runbooks/signoz-dashboard-api-key.md>.

## Local validation

`terragrunt` needs AWS credentials to evaluate the S3 remote state, so local
schema validation is done directly with OpenTofu:

```bash
cd <unit>
terragrunt init -backend=false   # generates _provider.tf / _backend.tf, then stops on AWS creds
tofu init -backend=false
tofu validate
tofu fmt -check -recursive
```

## Notes and assumptions

- **Data-links**: the provider supports dashboard/panel `links`, but target
  dashboard IDs are server-assigned. Links are intentionally left empty until
  the dashboards exist and their IDs are stable; use SigNoz's native navigation
  and the shared `homelab` tag in the meantime.
- **Cardinality**: panels group only by verified low-cardinality labels
  (`k8s.node.name`, `k8s.namespace.name`, `host.name`, `k8s_node_name`).
- **Thermal metric names**: the Pi 5 Thermal board uses `node_thermal_zone_temp`
  and `node_cpu_frequency_hertz` (node_exporter collectors scraped by the
  `signoz-k8s-infra` Prometheus preset). The Prometheus receiver relabels the
  node to `k8s_node_name`. Confirm the exact series/attribute names once data is
  flowing and adjust if the receiver renames them.
- **Time ranges**: `sandbox-runtime` and `strata-endpoint` default to 6 hours;
  `agent-traces` defaults to 1 hour. The maximum useful range is 15 days for
  traces and logs and 30 days for metrics, matching SigNoz retention.
- **Top-N**: the `agent-traces` volume, latency, and error panels show the top
  10 span names in the selected window, sorted descending.
- **Colon-containing names**: `strata:*` and `vllm:*` are quoted verbatim. The
  Prometheus receiver does not rename them, so the panels and the smoke check
  use the colon form.
- **Deliberate omissions**: `agent-traces` has no `Tool.execute` distribution, no
  model-call/tool-call split, and no spans-per-trace panel. The pinned agent build
  emits no `Tool.execute` or model-call span, and the provider has no two-stage
  aggregation over `trace_id` (and the spec forbids grouping a time series by
  `trace_id`). `strata-endpoint` has no per-consumer panels: `strata_consumer` is
  always `shared`, there is no finish-reason label, and there is no 401 counter.
- **Squid assertions**: the denial panel can legitimately show zero. The smoke
  check therefore asserts that Squid logs are arriving, not that requests are
  being denied.

## Notification channels

SigNoz v0.139.0 does not serve `/api/v2/notification_channels`, so the provider's
`signoz_notification_channel` resource cannot create channels. The
`homelab-overview` unit references the email channel `homelab-alerts-email` by
name; create it once in SigNoz under **Settings → Alert Channels**. SMTP is not
configured yet, so the channel records firing state in the UI.
