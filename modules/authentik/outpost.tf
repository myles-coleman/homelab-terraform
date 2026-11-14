resource "authentik_outpost" "traefik" {
  name = var.outpost_name
  type = "proxy"

  # The outpost must be told which providers it fronts. Dropping an application
  # from var.applications removes it here too, so a retired app stops being
  # authenticated rather than lingering as an orphan provider.
  protocol_providers = [
    for provider in authentik_provider_proxy.apps : provider.id
  ]
}
