# Channel: the rules API requires at least one channel, and this SigNoz
# instance (v0.139.0) only exposes the v1 channels API - provider 0.1.5 targets
# v2 and gets the UI's HTML back, which is why the channel is not managed here.
# Create it once in the UI as `homelab-alerts-email` (Settings - Alert
# Channels); the rule below references it by display name.
#
# Why this is a name and not a resource reference: there is no channel resource
# in provider 0.1.4, and 0.1.5's channel API does not exist on this version.

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
