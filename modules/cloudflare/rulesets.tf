# Edge protection for the Authentik login surface.
#
# The login page has to be publicly reachable — it is what issues logins for
# every other host — so the useful controls are throttling and a challenge on the
# admin interface rather than blocking the host.
#
# /api/ is deliberately excluded from both rules. The authentik Terraform
# provider talks to https://authentik.cowlab.org/api/v3/ from CI, and a challenge
# or a throttle there breaks plan and apply instead of protecting anything.

# Per-IP rate limits for the zone.
#
# Cloudflare allows exactly one ruleset per phase per zone, so every rate limit
# lives here. Creating a second `http_ratelimit` ruleset fails the apply with a
# conflict — that is what a standalone Copyparty ruleset did on the first
# attempt, after its tunnel route and DNS record had already been created.
#
# Rule 1 — Authentik login surface. The login page has to be publicly reachable,
# so the useful control is throttling the entry points an unauthenticated visitor
# can hit: the OAuth start/callback and the flow executor. This zone's plan only
# allows a 10-second period and a 10-second mitigation timeout, so use 10
# requests per 10 seconds (~60/min): far above a human login and far below a
# scripted attempt.
#
# Rule 2 — Copyparty. This is not an abuse filter in the same sense: the host is
# gated by Authentik. It is the bounded-usage commitment from spec 05. The limit
# is deliberately loose because the upload protocol is one request per chunk: a
# 1 GB file is ~11 POSTs of 96 MiB with up to six in parallel, so a login-style
# threshold would throttle legitimate transfers. 60 per 10 seconds (~6/s) bounds
# a script while staying clear of a browser upload.
resource "cloudflare_ruleset" "authentik_rate_limit" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "zone rate limits"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules = [{
    action      = "block"
    description = "Throttle Authentik login and OAuth entry points per source IP"
    enabled     = true
    expression  = "(http.host eq \"authentik.cowlab.org\" and (starts_with(http.request.uri.path, \"/source/oauth/\") or starts_with(http.request.uri.path, \"/flows/\")))"
    ratelimit = {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = 10
      mitigation_timeout  = 10
    }
    },
    {
      action      = "block"
      description = "Throttle Copyparty per source IP without throttling chunked uploads"
      enabled     = true
      expression  = "(http.host eq \"copyparty.cowlab.org\")"
      ratelimit = {
        characteristics     = ["cf.colo.id", "ip.src"]
        period              = 10
        requests_per_period = 60
        mitigation_timeout  = 10
      }
  }]
}

# Challenge the admin interface at the edge. Browsers solve it invisibly; the
# login flows and the API are untouched, so this does not affect SSO or CI.
resource "cloudflare_ruleset" "authentik_admin_challenge" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "authentik admin challenge"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [{
    action      = "managed_challenge"
    description = "Challenge the Authentik admin interface; login flows and API stay exempt"
    enabled     = true
    expression  = "(http.host eq \"authentik.cowlab.org\" and starts_with(http.request.uri.path, \"/if/admin\"))"
  }]
}
