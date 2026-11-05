# Capacity guardrail for the SigNoz ClickHouse volume (spec 26, task 4.0).
#
# The failure this prevents: the 40Gi volume reached 100%, the filesystem went
# read-only, ClickHouse crash-looped for two and a half days, and the terraform
# plan matrix went red behind it. The volume is now 80Gi, so 80% used is 16Gi
# free; the rule fires while there is still room to act.
#
# It lives in the existing dashboard unit because that unit already owns the
# signoz provider configuration and a bootstrap plan role. A dedicated alerts
# unit would need its own entry in bootstrap/oidc.tf and a manual first apply,
# which is more moving parts than one rule warrants.
#
# Channels: the rules API requires at least one. The provider's
# `signoz_notification_channel` resource posts to `/api/v2/notification_channels`,
# which SigNoz v0.139.0 does not serve (the request falls through to the UI and
# returns HTML 200). The channel is therefore created once via the v1 API
# (`POST /api/v1/channels`, see README.md) and referenced by name. This keeps the
# rule declarative while the channel lifecycle stays a documented operator step.

resource "signoz_rule" "clickhouse_volume_capacity" {
  alert      = "SigNoz ClickHouse volume above 80% used"
  alert_type = "METRIC_BASED_ALERT"
  rule_type  = "threshold_rule"

  annotations = {
    description = "The SigNoz ClickHouse PVC has {{$value}} bytes available, below the {{$threshold}}-byte (16Gi) warning line. At zero the filesystem goes read-only and ingestion stops."
    summary     = "ClickHouse volume above 80% used"
  }

  condition = {
    composite_query = {
      panel_type = "graph"
      query_type = "builder"
      unit       = "bytes"

      queries = [
        {
          builder_query = {
            type = "builder_query"
            spec = {
              metrics = {
                name   = "A"
                signal = "metrics"

                aggregations = [
                  {
                    metric_name       = "k8s.volume.available"
                    space_aggregation = "min"
                    time_aggregation  = "min"
                  },
                ]

                filter = {
                  expression = "k8s.persistentvolumeclaim.name = 'data-volumeclaim-template-chi-signoz-clickhouse-cluster-0-0-0'"
                }

                legend        = "{{k8s.persistentvolumeclaim.name}}"
                step_interval = "60"
              }
            }
          }
        },
      ]
    }

    selected_query_name = "A"

    thresholds = {
      basic = {
        kind = "basic"
        spec = [
          {
            channels   = ["homelab-alerts-email"]
            match_type = "all_the_times"
            name       = "critical"
            op         = "below"
            target     = 17179869184 # 16Gi: 80% of the 80Gi claim
          },
        ]
      }
    }
  }

  description = "The SigNoz ClickHouse PVC has under 16Gi free (80% of its 80Gi claim); act before it fills and goes read-only."

  evaluation = {
    rolling = {
      kind = "rolling"
      spec = {
        eval_window = "5m"
        frequency   = "1m"
      }
    }
  }

  labels = {
    component = "signoz"
    severity  = "warning"
  }

  notification_settings = {
    group_by = []
    renotify = {
      alert_states = ["firing"]
      enabled      = true
      interval     = "4h"
    }
  }

  schema_version = "v2alpha1"
}
