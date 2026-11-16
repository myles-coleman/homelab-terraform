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

# Enrollment allowlist.
#
# The Google source accepts any Google account, so without this anyone on the
# internet can complete enrollment and create a dormant Authentik account. This
# bound policy admits only the addresses in ALLOWED_EMAILS — the same list the
# Cloudflare Access application admits, read from the same repository secret, so
# the two cannot drift.
#
# `oauth_userinfo` is where the OAuth callback puts the provider's raw profile
# (sources/oauth/views/callback.py passes policy_context={"oauth_userinfo":
# raw_info}, and the flow manager merges that into the plan context). It is not
# request.context["source"], which is the Source object itself.
locals {
  enrollment_allowlist_expression = format(
    "return request.context.get('oauth_userinfo', {}).get('email', '').lower() in %s",
    jsonencode([for email in var.allowed_emails : lower(trimspace(email))]),
  )
}

resource "authentik_policy_expression" "enrollment_allowlist" {
  name       = "source-enrollment-email-allowlist"
  expression = local.enrollment_allowlist_expression
}

resource "authentik_policy_binding" "enrollment_allowlist" {
  target = data.authentik_flow.enrollment.id
  policy = authentik_policy_expression.enrollment_allowlist.id
  order  = 0
}
