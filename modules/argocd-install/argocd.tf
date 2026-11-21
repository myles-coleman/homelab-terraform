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

  # This chart renders argocd-secret from configs.secret.* only: it never renders
  # server.secretkey, and it renders admin.password only when
  # configs.secret.argocdServerAdminPassword is set. Both are instead written into
  # the live Secret by argocd-server at startup (InitializeSettings). With
  # force_update below, the provider runs `helm upgrade --force`, and helm
  # replaces every object in the release instead of patching it - so an apply
  # rebuilds the Secret's data from the manifest and drops those keys, which
  # surfaces as "server.secretkey is missing" on every API call that loads
  # settings.
  #
  # createSecret: false drops the Secret from the rendered manifest. Helm deletes
  # resources that disappear from a release manifest on upgrade, so the Secret
  # also has to carry `helm.sh/resource-policy: keep`; the ExternalSecret in
  # manifests/cluster/argocd-secret sets it. With both, helm never replaces or
  # deletes it, and ESO plus argocd-server own its data.
  secret:
    createSecret: false
EOF
  ]
}
