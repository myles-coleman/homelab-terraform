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
    # Origin is the Gateway's websecure listener, not plain HTTP: the web
    # entrypoint redirects to https, so a tunnel pointed at :80 would return a
    # 301 to the browser, which would come straight back through the tunnel and
    # loop.
    #
    # origin_server_name keeps certificate verification on. cloudflared dials the
    # service address (traefik.traefik.svc.cluster.local) but presents the
    # public hostname as SNI, which is what the Gateway's wildcard certificate
    # covers. no_tls_verify would also work and would verify nothing.
    ingress = [
      {
        hostname = "authentik.cowlab.org"
        service  = "https://traefik.traefik.svc.cluster.local:443"
        origin_request = {
          origin_server_name = "authentik.cowlab.org"
        }
      },
      {
        # Jellyfin streams video through this route. Cloudflare's service terms
        # restrict serving video over a proxied hostname on the Free plan and
        # point at Stream instead; this is discretionary enforcement, not a
        # byte counter, but it is the one route here that touches that rule.
        # Delete this block (and its DNS record) to keep Jellyfin LAN/tailnet
        # only — SSO still applies locally, the tunnel is what changes.
        hostname = "jellyfin.cowlab.org"
        service  = "https://traefik.traefik.svc.cluster.local:443"
        origin_request = {
          origin_server_name = "jellyfin.cowlab.org"
        }
      },
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
