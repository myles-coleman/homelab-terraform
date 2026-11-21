resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# 10.11.7 is the newest chart whose appVersion is ArgoCD v3.5.7; chart 10.12.0
# and later already track v3.6.x. The chart version, not an image tag, is what
# selects the ArgoCD release - keep this pin and that sentence together.
resource "helm_release" "argocd" {
  name         = "argocd"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  version      = "10.11.7"
  timeout      = 1200
  force_update = true
  atomic       = true
  namespace    = kubernetes_namespace.argocd.id
  # argocd-secret is owned by the ExternalSecret that the `argocd-secret`
  # Application creates from Vaultwarden (manifests/cluster/argocd-secret in
  # myles-coleman/homelab-cluster): the OIDC client secret that the external Dex
  # validates, plus server.secretkey. Terraform used to seed the client secret
  # from random_password and ESO then overwrote it - two owners, plus a window on
  # every apply where ArgoCD held a secret Dex no longer accepted. The bundled
  # dex-server must not reference either key: it is not the identity provider
  # (configs.cm.oidc.config points at the external Dex), so a cold install has
  # nothing to wait for before ESO runs. See configs.secret below for why the
  # chart must not render the Secret at all.
  values = [<<EOF
# Chart 10.0.0 flipped this default to true, so the upgrade created six
# NetworkPolicies in the argocd namespace. The cluster CNI is k3s' embedded
# flannel, which only accepts NetworkPolicy objects and does not enforce them,
# so they are inert today. Declared here so the change is a reviewed line
# instead of a silent chart-default shift; set false to opt out.
global:
  networkPolicy:
    create: true

server:
  replicas: 1
  metrics:
    enabled: true

controller:
  replicas: 1
  metrics:
    enabled: true

repoServer:
  replicas: 1
  metrics:
    enabled: true

dex:
  metrics:
    enabled: true

configs:
  cm:
    exec.enabled: true
    admin.enabled: true
    accounts.admin: apiKey

    url: https://${var.argocd_host}
    oidc.config: |
      name: Dex
      issuer: ${var.dex_url}
      clientID: argocd
      clientSecret: $oidc.sso.clientSecret
      requestedScopes: ["openid", "profile", "email", "groups"]

      allowedAudiences:
      - argocd
      - kubernetes

  rbac:
    policy.csv: |
      g, ${var.github_username}, role:admin
      g, Cgg0NDUwNTg1NRIGZ2l0aHVi, role:admin
    policy.default: role:readonly

  params:
    "server.insecure": true

  # Chart 10.x renders argocd-secret with only the keys under configs.secret.*,
  # and it never emits server.secretkey or admin.password - those are generated
  # by argocd-server into the live Secret at startup. With force_update below,
  # every release replace rewrites that Secret from the chart manifest and drops
  # them, which surfaces as "server.secretkey is missing" on every API call that
  # loads settings. Setting createSecret: false removes the Secret from the
  # release entirely, so Helm has nothing to replace; the Secret is left alone
  # and ESO + argocd-server own its data (see manifests/cluster/argocd-secret).
  secret:
    createSecret: false
EOF
  ]
}
