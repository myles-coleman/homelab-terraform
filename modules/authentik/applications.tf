resource "authentik_application" "apps" {
  for_each = var.applications

  name               = each.value.name
  slug               = each.value.slug
  protocol_provider  = authentik_provider_proxy.apps[each.key].id
  policy_engine_mode = "any"
  meta_publisher     = "homelab"

  # Deliberately no `group`: that field puts every user of a group into the app
  # launcher regardless of policy. Authorization is expressed as policy bindings
  # in policies.tf instead, so an application is reachable only by the groups
  # named in its `groups` list.
}
