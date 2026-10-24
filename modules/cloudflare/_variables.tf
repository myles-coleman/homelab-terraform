variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for importing existing zone"
  type        = string
}

variable "domain" {
  description = "The domain name for the Cloudflare zone"
  type        = string
  default     = "cowlab.org"
}

variable "lb_ip" {
  description = "The IP address for the load balancer"
  type        = string
}

variable "homelab_ip" {
  description = "The IP address for the homelab server"
  type        = string
}

variable "google_oauth_client_id" {
  description = "Google OAuth Client ID for Cloudflare Access"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth Client Secret for Cloudflare Access"
  type        = string
  sensitive   = true
}

variable "allowed_emails" {
  description = "Email addresses allowed to access applications via Cloudflare Access. The only input to the allow policy, so it must be neither empty nor malformed."
  type        = list(string)

  # GitHub Actions resolves a missing secret to an empty string rather than to an
  # absent variable, so a deleted ALLOWED_EMAILS reaches Terragrunt as "" and
  # splits into [""] - fail-closed (the policy emits exact-match `email`
  # includes, so nobody is admitted) but silent: the apply would rewrite the
  # Access policy with a dead rule and nothing would report it. Reject it here,
  # where the message can name the input that is wrong.
  validation {
    condition     = length(var.allowed_emails) > 0
    error_message = "allowed_emails is empty, so the Cloudflare Access policy would allow nobody. ALLOWED_EMAILS is a repository secret, not a variable: restore it (gh secret set ALLOWED_EMAILS) and re-plan."
  }

  validation {
    condition = alltrue([
      for email in var.allowed_emails :
      trimspace(email) != "" && can(regex("^[^@,;\\s]+@[^@,;\\s]+\\.[^@,;\\s]+$", email))
    ])
    error_message = "Every entry in ALLOWED_EMAILS must be a plain email address. A trailing or doubled comma leaves an empty entry that matches nobody, so the list is rejected rather than applied. Got: ${jsonencode(var.allowed_emails)}."
  }
}
