# The tailnet policy file, as a file: who may reach what, which tags exist, and
# which members can own them. It is the whole policy - Tailscale has no partial
# resource - so every change to access control in this tailnet shows up as a diff
# to `tailnet.hujson` and nothing else.
#
# The file was imported verbatim from the admin console; from the first apply on,
# this resource is what the tailnet runs on.
resource "tailscale_acl" "this" {
  acl = file("${path.module}/tailnet.hujson")

  # Both of these are Tailscale's defaults, written out because both are
  # load-bearing:
  #
  # - an apply cannot replace a policy this state does not own, so the first run
  #   has to be a reviewed `terragrunt import`, not an accident;
  # - destroying this unit must never restore Tailscale's allow-all default.
  overwrite_existing_content = false
  reset_acl_on_destroy       = false
}
