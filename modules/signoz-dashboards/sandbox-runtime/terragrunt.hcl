include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "signoz" {
  # The API token is read from the SIGNOZ_ACCESS_TOKEN environment variable, so
  # it is never written into this generated file or into Terraform state.
  endpoint = "${local.common.locals.signoz_endpoint}"
}
EOF
}
