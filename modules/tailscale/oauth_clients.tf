# The OAuth client GitHub Actions mints runner nodes with. Terraform owns its tag
# list so `tag:ci-plan` - defined in tailnet.hujson - is authorised in code rather
# than in the admin console (#15).
#
# Imported, not created: the credential already exists and every plan and apply
# authenticates with it. `terragrunt import tailscale_oauth_client.ci
# krXSC4fZMH11CNTRL` bound it to this address, and the plan after that import
# showed `scopes` unchanged, which is the check that matters: editing scopes here
# changes the credential CI uses to reach Tailscale at all.
#
# The description is the live one, kept as found. `tags` is mandatory whenever the
# scopes include `auth_keys`.
#
# `tag:ci-plan` was briefly added here and had to be taken back out: a node that
# asks for one tag out of a client's set is refused with "requested tags
# [tag:ci-plan] are invalid or not permitted", and with two tags on the client
# even `tag:ci` stops working. Plan jobs therefore get their own credential
# instead of a second tag on this one (#15).
resource "tailscale_oauth_client" "ci" {
  description = "GitHub Actions Runner"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci"]
}
