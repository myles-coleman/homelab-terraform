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
# Channels: the rules API requires at least one. This unit owns the channel as a
# Terraform resource again now that SigNoz v0.149.0 serves
# `/api/v2/notification_channels` (0.139.0 answered with the UI's HTML, which is
# why the channel lived outside Terraform for a while). The resource is imported,
# not created: the channel already exists and rules reference it by display name.
#
# The v1 -> v2 migration at 0.149.0 rewrote the channel's immutable `name` to a
# DNS-1123 label with a generated suffix, keeping the display name and the ID. The
# `name` below is the one that migration produced; `display_name` is what rules
# use, and is the value that must stay stable.
import {
  to = signoz_notification_channel.email
  id = "01a1a9d0-7030-7826-897c-1cd31ab6085f"
}

resource "signoz_notification_channel" "email" {
  name         = "homelab-alerts-email-acst754d"
  display_name = "homelab-alerts-email"

  config = {
    email = {
      kind = "email"
      spec = {
        to            = "mylescoleman05@gmail.com"
        send_resolved = true
      }
    }
  }
}

# The sandbox channel was created alongside the guardrail channel while the v2
# channel API was unavailable. Every rule now points at the guardrail channel, so
# this one is unused. It is imported here only so the next change can destroy it
# through Terraform rather than by hand.
import {
  to = signoz_notification_channel.sandbox_unused
  id = "01a1a9d0-444d-7a69-bd14-032ef9aebb8a"
}

resource "signoz_notification_channel" "sandbox_unused" {
  name         = "sandbox-alerts-email-9xm4zxb8"
  display_name = "sandbox-alerts-email"

  config = {
    email = {
      kind = "email"
      spec = {
        to            = "mylescoleman05@gmail.com"
        send_resolved = true
      }
    }
  }
}

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
            channels   = [signoz_notification_channel.email.display_name]
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
