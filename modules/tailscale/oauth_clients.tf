# The OAuth client GitHub Actions mints runner nodes with. Terraform owns its tag
# list so `tag:ci-plan` - which the policy file now defines - can be authorised in
# code instead of in the admin console (#15).
#
# It is imported, not created: the credential already exists and plans and
# applies authenticate with it. `terragrunt import tailscale_oauth_client.ci
# krXSC4fZMH11CNTRL` binds it to this address.
#
# The values below are the pre-import reading of the console, and the plan after
# that import is what proves them: it must show no change to `scopes` before this
# merges. Editing scopes here would change the credential every plan and apply
# authenticates with, and `tags` is mandatory whenever the scopes include
# `auth_keys`.
resource "tailscale_oauth_client" "ci" {
  description = "GitHub Actions CI runners (homelab-terraform)"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci"]
}
