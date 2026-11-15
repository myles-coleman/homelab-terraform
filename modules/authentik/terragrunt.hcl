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
  # No applications yet. Jellyfin is outside the cluster and is gated by its
  # Cloudflare Access application instead — the Traefik forward-auth route could
  # not reach a host with no in-cluster endpoints (EndpointSlice/Endpoints are
  # excluded in argocd-cm, ExternalName is unsupported by the Gateway provider).
  #
  # The first in-cluster application goes here. It also needs the shared
  # Middleware referenced from its HTTPRoute, plus a ReferenceGrant naming that
  # namespace.
  applications = {
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
  url = "${local.common_inputs.authentik_url}"
  # A variable reference, not an interpolation: the token is resolved by
  # OpenTofu from TF_VAR_authentik_token at run time, so no credential is ever
  # written into this generated file or into Terraform state. The provider
  # marks `token` as required and does not fall back to an environment variable
  # itself, which is why the reference has to be here.
  token = var.authentik_token
}
EOF
}
