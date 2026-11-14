# Flow slugs shipped by Authentik's default blueprint. They are looked up
# rather than created: replacing them is an Authentik-side decision, and these
# are the slugs the proxy provider expects for a standard consent-then-login
# round trip (implicit consent: no second confirmation page for a forward-auth
# redirect, which is the only workable UX for a transparent proxy).

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}
