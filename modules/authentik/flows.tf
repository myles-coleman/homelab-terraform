# Flow slugs shipped by Authentik's default blueprint. They are looked up rather
# than created: replacing them is an Authentik-side decision, and these are the
# slugs the proxy provider expects for a standard consent-then-login round trip
# (implicit consent: no second confirmation page for a forward-auth redirect,
# which is the only workable UX for a transparent proxy).
#
# The postconditions exist because the provider's flow data source does not fail
# when the API returns nothing: an undeployed or unreachable instance yields a
# null id, and the only error the caller sees is "The argument
# authorization_flow is required, but no definition was found" on the proxy
# provider — which names neither the flow nor the instance. Asserting on the read
# makes that failure legible.

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"

  lifecycle {
    postcondition {
      condition     = self.id != null && self.id != ""
      error_message = "No Authentik flow matched slug \"default-provider-authorization-implicit-consent\". Either Authentik is not deployed and reachable at the configured authentik_url, or its default blueprint has not been applied."
    }
  }
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"

  lifecycle {
    postcondition {
      condition     = self.id != null && self.id != ""
      error_message = "No Authentik flow matched slug \"default-provider-invalidation-flow\". Either Authentik is not deployed and reachable at the configured authentik_url, or its default blueprint has not been applied."
    }
  }
}
