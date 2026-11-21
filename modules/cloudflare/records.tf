resource "cloudflare_dns_record" "chat" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "chat.cowlab.org"
  type    = "A"
  content = var.homelab_ip
  ttl     = 1
}

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
# Keep these in step with the ingress list in tunnel.tf. A record without a
# matching ingress rule resolves to the tunnel and then gets the 404 catch-all.
resource "cloudflare_dns_record" "tunnel_authentik" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "authentik.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "tunnel_jellyseerr" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "jellyseerr.${var.domain}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "tunnel_openwebui" {
  zone_id = cloudflare_zone.cowlab.id
  name    = "openwebui.${var.domain}"
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
