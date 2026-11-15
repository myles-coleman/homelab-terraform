# One binding per (application, group) pair. This is the module's authorization
# model: an application with an empty `groups` list gets no binding, so
# `policy_engine_mode = "any"` admits nobody. Fail closed.
locals {
  app_group_bindings = merge([
    for app_key, app in var.applications : {
      for group_key in app.groups :
      "${app_key}/${group_key}" => {
        app   = app_key
        group = group_key
      }
    }
  ]...)
}

resource "authentik_policy_binding" "app_group" {
  for_each = local.app_group_bindings

  target = authentik_application.apps[each.value.app].uuid
  group  = authentik_group.this[each.value.group].id
  order  = 0
}

check "every_group_is_declared" {
  assert {
    condition = alltrue([
      for binding in values(local.app_group_bindings) :
      contains(keys(var.groups), binding.group)
    ])
    error_message = "An application references a group that is not declared in var.groups. Declare it there first; the policy binding would otherwise fail with an invalid index."
  }
}
