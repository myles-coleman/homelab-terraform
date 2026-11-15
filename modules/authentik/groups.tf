resource "authentik_group" "this" {
  for_each = var.groups

  name         = each.value.name
  is_superuser = each.value.is_superuser
}
