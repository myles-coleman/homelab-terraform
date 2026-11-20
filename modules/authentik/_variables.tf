variable "authentik_url" {
  description = "Base URL of the Authentik instance."
  type        = string
}

variable "allowed_emails" {
  description = "Email addresses permitted to complete source enrollment. Same list the Cloudflare Access policy admits. An empty list fails the plan rather than silently denying everyone."

  type = list(string)

  validation {
    condition     = length(var.allowed_emails) > 0
    error_message = "allowed_emails is empty, so the enrollment policy would deny every Google account including your own. ALLOWED_EMAILS is a repository secret: restore it (gh secret set ALLOWED_EMAILS) and re-plan."
  }

  validation {
    condition = alltrue([
      for email in var.allowed_emails :
      trimspace(email) != "" && can(regex("^[^@,;\\s]+@[^@,;\\s]+\\.[^@,;\\s]+$", email))
    ])
    error_message = "Every entry in ALLOWED_EMAILS must be a plain email address. Got: ${jsonencode(var.allowed_emails)}."
  }
}

variable "authentik_token" {
  description = "Authentik API token. Supplied at run time from TF_VAR_authentik_token, which CI maps from the AUTHENTIK_TOKEN secret. Never set it in a file."
  type        = string
  sensitive   = true

  # Defaulted to empty so `tofu validate` passes in the credential-free validate
  # job: the provider marks `token` as required, so it must appear in the
  # provider block, but validation must not need a real value. A plan or apply
  # that reaches the API without this set fails on authentication, which is the
  # loud failure we want.
  default = ""
}

variable "domain" {
  description = "Base domain for application hosts, e.g. cowlab.org."
  type        = string
}

variable "groups" {
  description = "Groups to create, keyed by the name applications use to reference them."
  type = map(object({
    name         = string
    is_superuser = optional(bool, false)
  }))
  default = {}
}

variable "applications" {
  description = "Applications to publish through the forward-auth outpost. An application is reachable only by members of the groups listed in groups[]. An empty list means nobody can use it, which is the safe default."

  type = map(object({
    name          = string
    slug          = string
    external_host = string
    mode          = optional(string, "forward_single")
    groups        = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for app in var.applications :
      contains(["proxy", "forward_single", "forward_domain"], app.mode)
    ])
    error_message = "Each application's mode must be one of: proxy, forward_single, forward_domain."
  }

  validation {
    condition = alltrue([
      for app in var.applications :
      startswith(app.external_host, "https://")
    ])
    error_message = "Each application's external_host must start with https:// — the forward-auth cookie is issued on that origin and Traefik only serves websecure."
  }
}

variable "oauth2_applications" {
  description = "Applications that speak OIDC natively, as opposed to the forward-auth proxy providers in var.applications. Reachable only by members of the groups listed here; an empty list admits nobody."

  type = map(object({
    name                   = string
    slug                   = string
    redirect_uris          = list(string)
    client_type            = optional(string, "confidential")
    groups                 = optional(list(string), [])
    access_code_validity   = optional(string, "minutes=5")
    access_token_validity  = optional(string, "hours=8")
    refresh_token_validity = optional(string, "days=30")
  }))
  default = {}

  validation {
    condition = alltrue([
      for app in var.oauth2_applications : length(app.redirect_uris) > 0
    ])
    error_message = "Every oauth2 application needs at least one redirect URI; without one the authorization request has nowhere to return to."
  }

  validation {
    condition = alltrue([
      for app in var.oauth2_applications : alltrue([
        for uri in app.redirect_uris : startswith(uri, "https://")
      ])
    ])
    error_message = "Every redirect URI must start with https:// — credentials are only issued over TLS, and a plain-http callback would be rejected at the token exchange."
  }

  validation {
    condition = alltrue([
      for app in var.oauth2_applications : contains(["confidential", "public"], app.client_type)
    ])
    error_message = "client_type must be either confidential or public."
  }
}

variable "outpost_name" {
  description = "Name of the proxy outpost the Traefik forwardAuth middleware authenticates against."
  type        = string
  default     = "traefik-forward-auth"
}
