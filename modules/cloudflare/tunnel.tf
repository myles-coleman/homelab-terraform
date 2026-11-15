# Random secret for tunnel authentication
resource "random_password" "tunnel_secret" {
  length = 64
}

# Cloudflare Tunnel for exposing services to the internet
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = "homelab-tunnel"
  config_src    = "cloudflare"
  tunnel_secret = base64sha256(random_password.tunnel_secret.result)
}

# Tunnel configuration - routes traffic to Traefik
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    # No service hostnames are published through the tunnel. jellyfin was
    # withdrawn together with its route in myles-coleman/homelab-cluster
    # (spec 04); the catch-all 404 is all that remains.
    ingress = [
      {
        # Catch-all rule (required) - returns 404 for unmatched requests
        service = "http_status:404"
      }
    ]
    warp_routing = {
      enabled = false
    }
  }
}

# Data source to get the tunnel token for use in Kubernetes
data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}
