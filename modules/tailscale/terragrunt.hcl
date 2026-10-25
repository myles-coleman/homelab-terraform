include {
  path = find_in_parent_folders("root.hcl")
}

# Credentials come from the environment - TAILSCALE_OAUTH_CLIENT_ID and
# TAILSCALE_OAUTH_CLIENT_SECRET, or TAILSCALE_API_KEY - which the provider reads
# by itself. They are never interpolated into this generated file: a generate
# block is written to disk on every run, so a credential placed there is a file
# waiting to be committed (#10).
generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "tailscale" {}
EOF
}
