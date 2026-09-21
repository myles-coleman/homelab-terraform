# Shared locals for every signoz-dashboards unit.
#
# This module intentionally deviates from the kubeconfig-based modules
# (cloudflare, argocd-*): the SigNoz provider talks to the SigNoz HTTP API, not
# the Kubernetes API. The API token is read by the provider from the
# SIGNOZ_ACCESS_TOKEN environment variable, so it is never written into the
# generated _provider.tf or Terraform state. The endpoint
# (https://signoz.cowlab.org) is reachable over Tailscale from CI.
#
# Read this file from a unit with:
#   locals { common = read_terragrunt_config(find_in_parent_folders("common.hcl")) }
# Terragrunt permits only one level of `include`, so this is a plain HCL file
# rather than a nested include.
locals {
  signoz_endpoint = get_env("SIGNOZ_ENDPOINT", "https://signoz.cowlab.org")
}
