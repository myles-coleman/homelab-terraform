#!/usr/bin/env bash
#
# Smoke check for the SigNoz dashboards managed by modules/signoz-dashboards.
#
# Every check queries the SigNoz v5 query_range API and fails (non-zero exit)
# when the response carries no data. A dashboard is represented by several
# checks, each a separate query:
#
#   principal  the series one or more panels are built on
#   heartbeat  a second, presence-only query for the board's ingest path, so
#              "ingest stopped" is not mistaken for "the board is idle"
#   extra      an additional series the board depends on (for example the Squid
#              denial log count)
#
# The payload shape follows the v5 API: metrics checks carry a metricName with
# time/space aggregations, while traces and logs checks carry expression
# aggregations such as count() or p95(duration_nano) plus a filter expression.
#
# Requires (unless --dry-run is given):
#   SIGNOZ_ENDPOINT       e.g. https://signoz.cowlab.org
#   SIGNOZ_ACCESS_TOKEN   a SigNoz service-account API key
#
# Usage:
#   ./signoz-dashboard-smoke.sh [--dry-run] [--only <dashboard>]
#
#   --dry-run        print every request payload, send nothing, exit 0
#   --only <name>    run only the checks for one dashboard
set -euo pipefail

usage() {
  sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'
}

dry_run=0
only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --only)
      [ $# -ge 2 ] || { echo "FAIL: --only requires a dashboard name" >&2; exit 2; }
      only="$2"
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$dry_run" -eq 0 ]; then
  : "${SIGNOZ_ENDPOINT:?SIGNOZ_ENDPOINT is required (or use --dry-run)}"
  : "${SIGNOZ_ACCESS_TOKEN:?SIGNOZ_ACCESS_TOKEN is required (or use --dry-run)}"
fi

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "FAIL: '$bin' is required" >&2; exit 1; }
done

end_ms="$(date +%s)000"
start_ms="$(( end_ms - 3600000 ))"

# One check per line: <dashboard>|<role>|<signal>|<filter>|<query>
#
#   signal  metrics | traces | logs
#   filter  a v5 filter expression, or empty
#   query   metrics: a metric name; traces/logs: an aggregation expression
#
# Filters must not contain a pipe.
checks=(
  # Existing boards: principal series plus an ingest heartbeat.
  "homelab-overview|principal|metrics||k8s.node.cpu.usage"
  "homelab-overview|heartbeat|metrics||k8s.node.cpu.usage"
  "network-speeds|principal|metrics||speedtest_download_bits_per_second"
  "network-speeds|heartbeat|metrics||speedtest_download_bits_per_second"
  "pi5-thermal|principal|metrics||node_thermal_zone_temp"
  "pi5-thermal|heartbeat|metrics||node_thermal_zone_temp"
  # Sandbox runtime: conntrack is the principal series; pod CPU is the ingest
  # heartbeat. The Squid check asserts that access logs are arriving, not that
  # requests are being denied: zero denials with a healthy volume is the goal.
  "sandbox-runtime|principal|metrics|k8s_node_name = 'sandbox-node'|node_nf_conntrack_entries"
  "sandbox-runtime|heartbeat|metrics|k8s.namespace.name = 'agent-sandbox'|k8s.pod.cpu.usage"
  "sandbox-runtime|squid-logs|logs|k8s.namespace.name = 'squid'|count()"
  # Strata endpoint: colon-containing names are quoted verbatim.
  "strata-endpoint|principal|metrics|host.name = 'bee-gpu-server'|strata:gpu_util"
  "strata-endpoint|heartbeat|metrics|host.name = 'bee-gpu-server'|strata:gpu_util"
  # Agent traces: the heartbeat is a count and the principal is a latency
  # expression. Both require the cluster-side ingest spec to be live.
  "agent-traces|heartbeat|traces|deployment.environment = 'agent-sandbox'|count()"
  "agent-traces|principal|traces|deployment.environment = 'agent-sandbox'|p95(duration_nano)"
)

build_payload() {
  local signal="$1" filter="$2" query="$3" role="$4"
  local aggregations

  if [ "$signal" = "metrics" ]; then
    if [ "$role" = "heartbeat" ]; then
      # Presence-only aggregation: one result per step while samples arrive.
      aggregations="$(jq -n --arg m "$query" \
        '[{metricName: $m, timeAggregation: "count", spaceAggregation: "sum"}]')"
    else
      aggregations="$(jq -n --arg m "$query" \
        '[{metricName: $m, timeAggregation: "avg", spaceAggregation: "avg"}]')"
    fi
  else
    aggregations="$(jq -n --arg e "$query" '[{expression: $e}]')"
  fi

  jq -n \
    --arg signal "$signal" \
    --arg filter "$filter" \
    --argjson aggregations "$aggregations" \
    --argjson start "$start_ms" \
    --argjson end "$end_ms" \
    '{
       start: $start,
       end: $end,
       requestType: "time_series",
       schemaVersion: "v1",
       compositeQuery: {
         queries: [
           {
             type: "builder_query",
             spec: (
               {
                 name: "A",
                 signal: $signal,
                 stepInterval: "60s",
                 aggregations: $aggregations
               }
               + (if $filter == "" then {} else { filter: { expression: $filter } } end)
             )
           }
         ]
       }
     }'
}

fail=0
matched=0

for entry in "${checks[@]}"; do
  IFS='|' read -r name role signal filter query <<<"$entry"

  if [ -n "$only" ] && [ "$only" != "$name" ]; then
    continue
  fi
  matched=$(( matched + 1 ))

  payload="$(build_payload "$signal" "$filter" "$query" "$role")"

  if [ "$dry_run" -eq 1 ]; then
    printf '### %s %s (%s)\n%s\n' "$name" "$role" "$signal" "$payload"
    continue
  fi

  if ! response="$(curl -sS -w $'\n%{http_code}' --max-time 30 \
    -X POST "${SIGNOZ_ENDPOINT%/}/api/v5/query_range" \
    -H "SIGNOZ-API-KEY: ${SIGNOZ_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$payload")"; then
    echo "FAIL ${name} ${role}: request error for ${query}"
    fail=1
    continue
  fi

  http_code="$(printf '%s' "$response" | tail -n1)"
  body="$(printf '%s' "$response" | sed '$d')"

  if [ "$http_code" != "200" ]; then
    echo "FAIL ${name} ${role}: HTTP ${http_code} for ${query}"
    fail=1
    continue
  fi

  if ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    echo "FAIL ${name} ${role}: malformed JSON response for ${query}"
    fail=1
    continue
  fi

  if printf '%s' "$body" | jq -e \
    '[.. | objects | select(has("series")) | .series | length] | any(. > 0)' \
    >/dev/null 2>&1; then
    echo "PASS ${name} ${role}: ${query} returned data"
  else
    echo "FAIL ${name} ${role}: no data returned for ${query}"
    fail=1
  fi
done

if [ "$dry_run" -eq 1 ]; then
  exit 0
fi

if [ "$matched" -eq 0 ]; then
  echo "FAIL: no checks matched '${only}'" >&2
  exit 2
fi

if [ "$fail" -ne 0 ]; then
  echo "Dashboard smoke check FAILED"
  exit 1
fi

echo "Dashboard smoke check PASSED"
