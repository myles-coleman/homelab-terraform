include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common_inputs = yamldecode(file(find_in_parent_folders("common-inputs.yaml")))

  # Same source as the Cloudflare Access policy: ALLOWED_EMAILS is the single
  # list of people who may use this homelab, and it is a repository secret rather
  # than a file so addresses stay out of this public repo.
  allowed_emails = [
    for email in split(",", get_env("ALLOWED_EMAILS")) : trimspace(replace(email, "\"", ""))
  ]
}

inputs = {
  authentik_url = local.common_inputs.authentik_url
  domain        = local.common_inputs.domain

  allowed_emails = local.allowed_emails

  groups = {
    homelab = {
      name = "homelab"
    }
  }

  # Each application is reachable only by the groups listed here. Adding an app
  # does not expose it: the Traefik HTTPRoute must also carry the shared
  # `authentik` forward-auth Middleware and a ReferenceGrant must name that
  # route's namespace. For remote access it also needs a proxied DNS record; the
  # tunnel is a single wildcard rule, so the record is the whole change there.
  #
  # The map keys are resource addresses, not names: `jellyseerr` and `openwebui`
  # are kept as keys because changing a key destroys and recreates the provider,
  # the application and its policy bindings - a window in which nothing gated can
  # authenticate - for a cosmetic gain. `name` and `external_host` are what users
  # actually see.
  #
  # Seerr keeps its own login behind the gate: no stable release supports OIDC or
  # forward-auth, so the gate is a perimeter control, not single sign-on.
  applications = {
    jellyseerr = {
      name          = "Seerr"
      slug          = "jellyseerr"
      external_host = "https://seerr.${local.common_inputs.domain}"
      groups        = ["homelab"]
    }
    openwebui = {
      name          = "Open WebUI"
      slug          = "openwebui"
      external_host = "https://chat.${local.common_inputs.domain}"
      groups        = ["homelab"]
    }
    copyparty = {
      name          = "Copyparty"
      slug          = "copyparty"
      external_host = "https://copyparty.${local.common_inputs.domain}"
      groups        = ["homelab"]
    }
    # YouTube URL -> English transcript. The route and its ReferenceGrant live in
    # homelab-cluster (manifests/cluster/transcript); this entry is the identity
    # side. No proxied DNS record: the hostname resolves through the wildcard and
    # is LAN-only, so remote browsers cannot reach it.
    transcript = {
      name          = "Transcript"
      slug          = "transcript"
      external_host = "https://transcript.${local.common_inputs.domain}"
      groups        = ["homelab"]
    }
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
