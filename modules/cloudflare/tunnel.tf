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
    ingress = [
      {
        # Jellyfin is outside the cluster and gated by its Cloudflare Access
        # application, so the tunnel goes straight to the host rather than
        # through Traefik. That keeps video on one hop and avoids the fact that
        # Traefik's Gateway provider cannot reference an address outside the
        # cluster (no Endpoints/EndpointSlice from Git — both are excluded in
        # argocd-cm — and ExternalName is refused).
        #
        # Cloudflare's service terms restrict serving video over a proxied
        # hostname on the Free plan and point at Stream instead; this is
        # discretionary enforcement, not a byte counter, but it is the one rule
        # this route touches. Delete this block and its DNS record to keep
        # Jellyfin internal only.
        hostname = "jellyfin.cowlab.org"
        service  = "http://10.0.0.150:8096"
      },
      {
        # One rule for every in-cluster hostname.
        #
        # Previously each remotely reachable host had its own ingress rule and
        # its own origin_server_name, so publishing a service meant editing this
        # file, adding a DNS record, and keeping the two in step. match_sn_ito_host
        # replaces the per-host origin_server_name: cloudflared presents the
        # request's Host as SNI, which the Gateway's *.cowlab.org certificate
        # covers. Adding a host is now a proxied CNAME (records.tf) plus an
        # HTTPRoute in the cluster repo — and once external-dns owns the records,
        # only the HTTPRoute.
        #
        # `match_sn_ito_host` is spelled that way in the provider schema
        # (cloudflare/cloudflare 5.18.0, zero_trust_tunnel_cloudflared_config);
        # it maps to Cloudflare's matchSNItoHost. Do not "fix" it.
        #
        # Order matters: this wildcard must come after the rule that leaves the
        # cluster, and before the required catch-all.
        hostname = "*.cowlab.org"
        service  = "https://traefik.traefik.svc.cluster.local:443"
        origin_request = {
          match_sn_ito_host = true
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
