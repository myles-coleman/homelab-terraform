# Terraform does not own the tailnet policy yet: this reads it.
#
# The plan is the point. Reading the policy file needs a real Tailscale trust
# credential (`policy_file` scope), so a successful plan here proves the
# credential, the provider wiring and the CI plumbing before any of it is allowed
# to write. `tailscale_acl.this` in the next commit replaces this data source
# with the resource, once the live policy has been imported into state and the
# file it will manage exists in this directory.
data "tailscale_acl" "live" {}

output "live_policy_sha256" {
  description = "Hash of the tailnet policy the API currently holds; changes whenever someone edits it in the admin console"
  value       = sha256(data.tailscale_acl.live.json)
}
