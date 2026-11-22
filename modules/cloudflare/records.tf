# DNS records for cowlab.org.
#
# Three shapes, and the shape decides whether a record is needed at all:
#
#   * in-cluster, LAN only   -> nothing here. The *.cowlab.org wildcard below
#                               already points at the load balancer, and Traefik
#                               routes the hostname.
#   * in-cluster, remote     -> a proxied CNAME to the tunnel, so Cloudflare
#                               carries the traffic and cloudflared dials Traefik.
#                               The tunnel itself has one wildcard ingress rule
#                               (see tunnel.tf), so this record is the only
#                               per-host thing left.
#   * outside the cluster    -> a plain A record to var.homelab_ip.
resource "cloudflare_dns_record" "npm" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "npm.cowlab.org"
  type    = "A"
  content = var.homelab_ip
  ttl     = 1
}

resource "cloudflare_dns_record" "pihole" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "pihole.cowlab.org"
  type    = "A"
  content = var.homelab_ip
  ttl     = 1
}

resource "cloudflare_dns_record" "pikvm" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "pikvm.cowlab.org"
  type    = "A"
  content = var.homelab_ip
  ttl     = 1
}

resource "cloudflare_dns_record" "vaultwarden" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "vaultwarden.cowlab.org"
  type    = "A"
  content = var.homelab_ip
  ttl     = 1
}

resource "cloudflare_dns_record" "lb_wildcard" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "*.cowlab.org"
  type    = "A"
  content = var.lb_ip
  ttl     = 1
}

# Tunnel hostnames.
#
# These are explicit CNAMEs to the tunnel, so they override the *.cowlab.org
# wildcard A record that points at the LAN address. proxied must stay true: the
# tunnel only receives traffic for proxied records, and an unproxied CNAME would
# point browsers at cfargotunnel.com directly.
#
# A record here no longer needs a matching rule in tunnel.tf: that file holds one
# wildcard ingress rule, so the record is the whole per-host change. This is the
# layer external-dns will own next; until it does, adding a remotely reachable
# service means adding one of these blocks.

# Transition alias: kept so that bookmarks to the pre-rename hostname still work
# remotely, where the cluster's 301 can only be reached through the tunnel.
# Delete alongside the matching `httproute-legacy-host.yaml` in the cluster repo.
resource "cloudflare_dns_record" "tunnel_jellyseerr" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "jellyseerr.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# `authentik.cowlab.org` had a record here until the rename to auth.cowlab.org
# was finished. It was withdrawn only after the route stopped serving it and the
# Google redirect URI for it was removed, so nothing pointed at a dead host on the
# way out. Removing the record is what unpublishes the name; the *.cowlab.org
# wildcard still resolves it inside the LAN, where Traefik now answers 404.
resource "cloudflare_dns_record" "tunnel_seerr" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "seerr.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Transition alias: see tunnel_jellyseerr.
resource "cloudflare_dns_record" "tunnel_openwebui" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "openwebui.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# chat.cowlab.org used to be an A record to var.homelab_ip, where Nginx Proxy
# Manager answered with its "Default Site" and had no certificate for the name
# (hence `tlsv1 unrecognized name` on 443). It now belongs to the cluster's chat
# UI, so it becomes a tunnel hostname like the rest.
resource "cloudflare_dns_record" "tunnel_chat" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "chat.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# The identity provider has to be reachable remotely: a remote browser is sent
# here by the forward-auth outpost before it can reach any gated application.
resource "cloudflare_dns_record" "tunnel_auth" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "auth.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "tunnel_copyparty" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "copyparty.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "tunnel_jellyfin" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "jellyfin.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
