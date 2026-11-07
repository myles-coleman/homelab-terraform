resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "random_password" "client_secret" {
  length  = 20
  special = false
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
  env:
    - name: ARGOCD_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: argocd-secret
          key: oidc.sso.clientSecret

configs:
  secret:
    extra:
      oidc.sso.clientID: argocd
      oidc.sso.clientSecret: ${random_password.client_secret.result}

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
EOF
  ]
}
