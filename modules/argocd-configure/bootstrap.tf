# The root Application's project. Before this existed, the Application ran under
# ArgoCD's `default` project, which permits every source repository, every
# destination and every kind - so whatever `manifests/bootstrap` in the cluster
# repository contained would be applied with cluster-wide authority, and this
# repository could not bound it (#17). A project gives that bound a home here:
# one source repository, one destination namespace, and nothing cluster-scoped.
#
# What it constrains is the *root* Application. The 46 Applications it creates
# still run under the sibling repository's `default` project, which this tree
# cannot change; bounding those needs a change there.
resource "kubernetes_manifest" "bootstrap_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "bootstrap"
      namespace = "argocd"
    }
    spec = {
      description = "Root Application: creates the bootstrap Applications in argocd, from the cluster repository only"

      sourceRepos = ["https://github.com/myles-coleman/homelab-cluster"]

      destinations = [
        {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        },
      ]

      # The root writes Application objects and nothing else: cluster-scoped
      # kinds, ConfigMaps, anything a compromised or mistaken manifest adds, are
      # rejected by the project instead of applied.
      clusterResourceWhitelist = []

      namespaceResourceWhitelist = [
        {
          group = "argoproj.io"
          kind  = "Application"
        },
      ]
    }
  }

  field_manager {
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "bootstrap" {
  # `project` below has to exist first: ArgoCD rejects an Application whose
  # project it cannot find.
  depends_on = [kubernetes_manifest.bootstrap_project]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "bootstrap"
      namespace = "argocd"
    }
    spec = {
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      project = "bootstrap"
      source = {
        path           = "manifests/bootstrap"
        repoURL        = "https://github.com/myles-coleman/homelab-cluster"
        targetRevision = "main"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = false
        }
        retry = {
          backoff = {
            duration    = "30s"
            factor      = 2
            maxDuration = "2m"
          }
          limit = 5
        }
      }
    }
  }
  field_manager {
    force_conflicts = true
  }
}
