resource "authentik_provider_proxy" "apps" {
  for_each = var.applications

  name               = each.value.name
  external_host      = each.value.external_host
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
  mode               = each.value.mode

  # The outpost forwards to the app over the in-cluster Traefik Service, and
  # every backend behind it speaks plain HTTP, so origin certificate validation
  # never applies. Leaving this at the provider default (true) makes the outpost
  # reject the internal hop for no security benefit.
  internal_host_ssl_validation = false

  # Eight hours: long enough that media sessions are not interrupted, short
  # enough that a removed user loses access the same day.
  access_token_validity = "hours=8"
}
