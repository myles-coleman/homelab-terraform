include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common_inputs = yamldecode(file(find_in_parent_folders("common-inputs.yaml")))
}

inputs = {
  authentik_url = local.common_inputs.authentik_url
  domain        = local.common_inputs.domain

  groups = {
    homelab = {
      name = "homelab"
    }
  }

  # Each application is reachable only by the groups listed here. Adding an app
  # does not expose it: the Traefik IngressRoute must also carry the `authentik`
  # forwardAuth middleware, and the tunnel must route its hostname.
  applications = {
    jellyfin = {
      name          = "Jellyfin"
      slug          = "jellyfin"
      external_host = "https://jellyfin.${local.common_inputs.domain}"
      mode          = "forward_single"
      groups        = ["homelab"]
    }

    # sonarr = {
    #   name          = "Sonarr"
    #   slug          = "sonarr"
    #   external_host = "https://sonarr.${local.common_inputs.domain}"
    #   groups        = ["homelab"]
    # }
  }
}

generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "authentik" {
  # The API token is read from the AUTHENTIK_TOKEN environment variable, so it
  # is never written into this generated file or into Terraform state.
  url = "${local.common_inputs.authentik_url}"
}
EOF
}
