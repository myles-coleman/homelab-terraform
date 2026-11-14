terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      # Tracks the Authentik server release this cluster deploys (2026.5.x).
      # The provider's API surface moves with the server's, so bump these
      # together rather than independently.
      version = "~> 2026.5"
    }
  }
}
