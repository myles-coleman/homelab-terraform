output "outpost_id" {
  description = "ID of the proxy outpost. The Traefik forwardAuth middleware reaches it at authentik-outpost.authentik.svc.cluster.local:9000."
  value       = authentik_outpost.traefik.id
}

output "outpost_name" {
  description = "Name of the proxy outpost, as shown in the Authentik UI."
  value       = authentik_outpost.traefik.name
}

output "group_ids" {
  description = "Map of declared group key to Authentik group ID."
  value       = { for key, group in authentik_group.this : key => group.id }
}

output "applications" {
  description = "Map of application key to its slug and policy-provider binding."
  value = {
    for key, app in authentik_application.apps : key => {
      id                = app.id
      uuid              = app.uuid
      slug              = app.slug
      provider_id       = authentik_provider_proxy.apps[key].id
      authorized_groups = var.applications[key].groups
    }
  }
}
