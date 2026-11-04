# Sandbox + Strata detection rules (issue #74).
#
# These are the first four signals that can be expressed against telemetry the
# cluster actually has today. They are deliberately few: every rule below is
# backed by a series that the collection path (sandbox-telemetry, node-exporter,
# signoz-k8s-infra) is known to produce.
#
# Rules live in SigNoz's control-plane database, not in ClickHouse, so they are
# managed here rather than as Kubernetes manifests. The provider talks to the
# SigNoz HTTP API; CI supplies SIGNOZ_ENDPOINT and SIGNOZ_ACCESS_TOKEN.
#
# Deliberately absent:
#
#   * Strata 401 rate. Strata exposes no auth-failure counter, and its logs do
#     not record rejected requests either, so there is no honest series to alert
#     on. Adding one is an upstream/engine-image change, not a scrape change.
#   * gVisor `runsc` OOM/start failures. The debug logs live on the guest volume
#     (`/var/lib/runsc-logs`) and are not ingested yet. The pod-restart rule is
#     the coarse proxy until the sampled filelog path lands.
#   * "sustained network tx outside the proxy path". The guest egress filter
#     drops silently and exposes no counter; the sandbox pod's network bytes are
#     available, but a threshold there would be a false-positive generator
#     without a baseline.
#
# The two follow-ups are tracked on issue #74 rather than being faked here with
# a rule that can never evaluate to true.

locals {
  # One rolling evaluation shape for every rule keeps the alert history easy to
  # read: a 5-minute window, evaluated once a minute.
  rolling_evaluation = {
    rolling = {
      kind = "rolling"
      spec = {
        eval_window = "5m"
        frequency   = "1m"
      }
    }
  }

  # No notification channel is created here. The cluster has none configured;
  # adding a webhook URL without the operator's endpoint would only create a
  # permanently failing notification path. The rules still fire and appear in
  # SigNoz's alert history, which is what the acceptance evidence needs.
  notification_settings = {
    renotify = {
      enabled      = true
      interval     = "4h"
      alert_states = ["firing"]
    }
  }
}

# ── 1. Sandbox pod restarted ───────────────────────────────────────────────────
# `changes()` rather than `increase()`: kubelet reports the restart count as a
# gauge, and a pod replacement resets it to zero. Counting label/value changes
# catches both a same-pod restart and a fresh pod.
resource "signoz_rule" "sandbox_pod_restarted" {
  alert          = "Sandbox pod restarted"
  alert_type     = "METRIC_BASED_ALERT"
  rule_type      = "promql_rule"
  schema_version = "v2alpha1"
  description    = "The OpenCode sandbox container restarted in the last 10 minutes. A gVisor crash, an OOM kill, or a probe failure is a security-relevant event on the untrusted node."

  annotations = {
    summary     = "Sandbox container restarted"
    description = "pod={{$k8s.pod.name}} namespace={{$k8s.namespace.name}} — inspect the previous container log and /var/lib/runsc-logs on sandbox-node."
  }

  condition = {
    composite_query = {
      panel_type = "graph"
      query_type = "promql"
      unit       = "count"
      queries = [
        {
          promql = {
            type = "promql"
            spec = {
              name  = "A"
              query = <<-PROMQL
                sum by ("k8s.pod.name") (
                  changes({__name__="k8s.container.restarts", "k8s.namespace.name"="agent-sandbox"}[10m])
                )
              PROMQL
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
            name       = "critical"
            match_type = "at_least_once"
            op         = "above"
            target     = 0
          },
        ]
      }
    }
  }

  evaluation            = local.rolling_evaluation
  notification_settings = local.notification_settings
  labels = {
    severity = "critical"
    signal   = "sandbox-availability"
  }
}

# ── 2. Strata metrics stopped ──────────────────────────────────────────────────
# `up` comes from the sandbox-telemetry collector's prometheus receiver
# (`report_extra_scrape_metrics: true`). alert_on_absent covers the case where
# the collector itself is gone and `up` is not produced at all.
resource "signoz_rule" "strata_scrape_down" {
  alert          = "Strata metrics scrape is down"
  alert_type     = "METRIC_BASED_ALERT"
  rule_type      = "promql_rule"
  schema_version = "v2alpha1"
  description    = "The sandbox-telemetry collector has not scraped Strata successfully for 5 minutes. The model backend may be down, or the tailnet path from sandbox-node to bee-gpu-server has broken."

  annotations = {
    summary     = "Strata /metrics is not being scraped"
    description = "No successful scrape of 100.127.170.8:8080/metrics. Check docker-strata on bee-gpu-server and the sandbox-node tailnet route before suspecting the collector."
  }

  condition = {
    composite_query = {
      panel_type = "graph"
      query_type = "promql"
      unit       = "count"
      queries = [
        {
          promql = {
            type = "promql"
            spec = {
              name  = "A"
              query = "max(up{job=\"strata\"})"
            }
          }
        },
      ]
    }

    selected_query_name = "A"
    alert_on_absent     = true
    thresholds = {
      basic = {
        kind = "basic"
        spec = [
          {
            name       = "critical"
            match_type = "at_least_once"
            op         = "below"
            target     = 1
          },
        ]
      }
    }
  }

  evaluation            = local.rolling_evaluation
  notification_settings = local.notification_settings
  labels = {
    severity = "critical"
    signal   = "strata-availability"
  }
}

# ── 3. Guest conntrack table pressure ─────────────────────────────────────────
# node-exporter on sandbox-node runs with the conntrack collector. A scan, a
# stuck flow, or a SYN flood fills the guest's table before anything else shows
# it. 80% is the warning line; 100% starts dropping new connections.
resource "signoz_rule" "sandbox_conntrack_pressure" {
  alert          = "Sandbox guest conntrack table is over 80%"
  alert_type     = "METRIC_BASED_ALERT"
  rule_type      = "promql_rule"
  schema_version = "v2alpha1"
  description    = "The sandbox guest's conntrack table is close to its limit. This is the first saturation signal for an egress scan or a stuck proxy flow."

  annotations = {
    summary     = "Conntrack table pressure on sandbox-node"
    description = "node={{$k8s_node_name}} entries={{$value}}. Check `conntrack -L` and the squid access log before flushing anything."
  }

  condition = {
    composite_query = {
      panel_type = "graph"
      query_type = "promql"
      unit       = "percentunit"
      queries = [
        {
          promql = {
            type = "promql"
            spec = {
              name  = "A"
              query = <<-PROMQL
                max by ("k8s_node_name") ({__name__="node_nf_conntrack_entries", "k8s_node_name"="sandbox-node"})
                /
                max by ("k8s_node_name") ({__name__="node_nf_conntrack_entries_limit", "k8s_node_name"="sandbox-node"})
              PROMQL
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
            name       = "warning"
            match_type = "at_least_once"
            op         = "above"
            target     = 0.8
          },
        ]
      }
    }
  }

  evaluation            = local.rolling_evaluation
  notification_settings = local.notification_settings
  labels = {
    severity = "warning"
    signal   = "sandbox-network"
  }
}

# ── 4. Squid denied egress ────────────────────────────────────────────────────
# The proxy denies everything (the sandbox has no internet at all), so any
# TCP_DENIED line is an attempt, not routine noise. The container log is already
# ingested by the k8s-infra filelog receiver; this rule counts it.
resource "signoz_rule" "squid_denied_egress" {
  alert          = "Sandbox attempted denied egress through Squid"
  alert_type     = "LOGS_BASED_ALERT"
  rule_type      = "threshold_rule"
  schema_version = "v2alpha1"
  description    = "A request reached the deny-all Squid proxy. On a sandbox with no internet this is either a prompt-injection egress attempt or a misconfigured tool."

  annotations = {
    summary     = "Squid denied a sandbox egress request"
    description = "Read the squid container log line to see the requested host. The proxy denies by design; the attempt is the signal."
  }

  condition = {
    composite_query = {
      panel_type = "graph"
      query_type = "builder"
      unit       = "count"
      queries = [
        {
          builder_query = {
            type = "builder_query"
            spec = {
              logs = {
                name          = "A"
                signal        = "logs"
                filter        = { expression = "body LIKE '%TCP_DENIED%'" }
                aggregations  = [{ expression = "count()" }]
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
            name       = "critical"
            match_type = "at_least_once"
            op         = "above"
            target     = 0
          },
        ]
      }
    }
  }

  evaluation            = local.rolling_evaluation
  notification_settings = local.notification_settings
  labels = {
    severity = "critical"
    signal   = "sandbox-egress"
  }
}
