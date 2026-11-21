# Edge protection for the Authentik login surface.
#
# The login page has to be publicly reachable — it is what issues logins for
# every other host — so the useful controls are throttling and a challenge on the
# admin interface rather than blocking the host.
#
# /api/ is deliberately excluded from both rules. The authentik Terraform
# provider talks to https://authentik.cowlab.org/api/v3/ from CI, and a challenge
# or a throttle there breaks plan and apply instead of protecting anything.

# Per-IP rate limit on the entry points an unauthenticated visitor can hit: the
# OAuth start/callback and the flow executor. This zone's plan only allows a
# 10-second period and a 10-second mitigation timeout, so use 10 requests per
# 10 seconds (~60/min) and a 10-second block: far above a human login and far
# below a scripted attempt.
resource "cloudflare_ruleset" "authentik_rate_limit" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "authentik login rate limit"
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
