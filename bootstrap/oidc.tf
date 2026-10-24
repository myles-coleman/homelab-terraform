terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    ManagedBy = "Terraform"
  }
}

# Apply role. GitHub puts the *environment* in the subject claim when a job
# declares one, so the apply job (which uses `environment: deploy`) presents
# `environment:deploy` rather than a ref. Trusting only that shape means no
# arbitrary branch or pull request can assume AdministratorAccess.
data "aws_iam_policy_document" "github_actions_assume_operations" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:myles-coleman@44505855/homelab-terraform@1329076037:environment:deploy",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Plan role, used by credentialed plan runs, which only ever happen on a push to
# a branch of this repository (.github/workflows/deploy.yaml). Trust is anchored
# on that ref, because it is the one subject shape a fork cannot produce: a
# fork's push carries the fork's own owner and repository ids, and pushing to a
# branch here needs write access here.
#
# `pull_request` is deliberately absent. A pull-request run presents
# `repo:...:pull_request` whether its head branch lives in this repository or in
# a fork, so that subject cannot express "same repository only"; the `if:` that
# excludes forks lives in the workflow file the pull request itself supplies, so
# it is not an authorization boundary. Nothing on the pull_request path asks for
# AWS credentials at all: those runs get the formatters and a backend-less
# validate.
data "aws_iam_policy_document" "github_actions_assume_plan" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Any branch in this repository, including `main`. `*` also matches `/`,
      # so namespaced branch names such as `feat/plan-trust` are covered.
      values = [
        "repo:myles-coleman@44505855/homelab-terraform@1329076037:ref:refs/heads/*",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "terraform_state_operations" {
  statement {
    sid    = "AllowS3BucketOperations"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = ["arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"]
  }

  statement {
    sid    = "AllowS3StateFileOperations"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = ["arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"]
  }
}

resource "aws_iam_policy" "terraform_state_operations" {
  name        = "terraform-state-access"
  description = "Allows GitHub Actions to manage Terraform state in S3"
  policy      = data.aws_iam_policy_document.terraform_state_operations.json

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "terraform_operations" {
  name               = "terraform-operations"
  description        = "Role assumed by GitHub Actions to apply Terraform changes (administrative)"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_operations.json

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_state_operations" {
  role       = aws_iam_role.terraform_operations.name
  policy_arn = aws_iam_policy.terraform_state_operations.arn
}

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_operations.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------
# Plan roles: one per unit, so a credentialed plan can read only the state it is
# planning and write only the one lock file it needs. Kept separate from the
# apply role so a plan run never holds AdministratorAccess.
#
# A unit's state key is `${path_relative_to_include()}/terraform.tfstate`
# (root.hcl), so the unit path is also the S3 prefix that scopes it. The role
# name drops the `modules/` segment and flattens the rest, which is the
# `plan_role` the plan matrix in deploy.yaml carries, e.g.
# modules/signoz-dashboards/pi5-thermal plans as
# terraform-plan-signoz-dashboards-pi5-thermal. deploy.yaml composes those ARNs
# from the AWS_PLAN_ROLE_ARN family prefix, so adding a unit here and to the
# matrix is enough - there is no per-unit repository variable.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  # Keep in sync with the plan matrix in .github/workflows/deploy.yaml. A unit
  # missing here has no role to assume, so its plan fails rather than falling
  # back to a broader identity.
  plan_units = toset([
    "modules/argocd-configure",
    "modules/argocd-install",
    "modules/cloudflare",
    "modules/s3-backups",
    "modules/signoz-dashboards/homelab-overview",
    "modules/signoz-dashboards/network-speeds",
    "modules/signoz-dashboards/pi5-thermal",
  ])

  # Role names drop the `modules/` segment and flatten the rest, which is the
  # same `plan_role` the plan matrix in deploy.yaml carries. GitHub workflow
  # expressions have no `replace()`, so that value cannot be computed there; this
  # local and the matrix are the pair that has to stay in step.
  plan_role_names = {
    for unit in local.plan_units :
    unit => "terraform-plan-${replace(trimprefix(unit, "modules/"), "/", "-")}"
  }

  # What modules/s3-backups creates, spelled out here because bootstrap cannot
  # read that unit's inputs. Drift is loud, not silent: a rename in the unit
  # turns into AccessDenied on its next plan. Keep in sync with bucket_name in
  # modules/s3-backups/terragrunt.hcl and the `${cluster_name}-...` names in
  # modules/s3-backups/policy.tf.
  backup_bucket     = "myles-homelab-backups"
  backup_iam_user   = "homelab-k3s-cluster-longhorn-backup-user"
  backup_iam_policy = "homelab-k3s-cluster-longhorn-backup-policy"
}

data "aws_iam_policy_document" "terraform_plan" {
  for_each = local.plan_units

  # Object reads stop at the unit's own prefix. Before this split every plan
  # could read every other unit's state, which holds the tunnel secret, the
  # ArgoCD SSO client secret and the Longhorn access key.
  statement {
    sid       = "ReadUnitState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/${each.key}/*"]
  }

  # Bucket-level reads take no key or prefix, and they return metadata rather
  # than object bodies, so they stay on the bucket itself. s3:ListBucket is not
  # granted: the backend addresses its state and lock by exact key.
  statement {
    sid    = "ReadStateBucketConfig"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  # `use_lockfile = true` in root.hcl takes the lock by writing
  # `<key>.tflock` and deleting it on release. This is the only write a plan role
  # gets, and only for its own unit's lock.
  statement {
    sid       = "StateLockOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/${each.key}/terraform.tfstate.tflock"]
  }

  # -------------------------------------------------------------------------
  # modules/s3-backups is the only unit that talks to AWS, and its refresh needs
  # the backup bucket's configuration and that one user and policy. Everything
  # below is attached to its role alone rather than to all seven.
  # -------------------------------------------------------------------------

  dynamic "statement" {
    for_each = each.key == "modules/s3-backups" ? [1] : []

    content {
      sid    = "ReadBackupBucketConfig"
      effect = "Allow"
      actions = [
        "s3:GetAccelerateConfiguration",
        "s3:GetBucketAcl",
        "s3:GetBucketCORS",
        "s3:GetBucketLocation",
        "s3:GetBucketLogging",
        "s3:GetBucketNotification",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketOwnershipControls",
        "s3:GetBucketPolicy",
        "s3:GetBucketPolicyStatus",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketTagging",
        "s3:GetBucketVersioning",
        "s3:GetBucketWebsite",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        # Versioning on this bucket is suspended and nothing lists versions, so
        # s3:ListBucketVersions is gone. s3:ListBucket is kept: it is confined to
        # this one bucket and costs nothing to carry.
        "s3:ListBucket",
      ]
      resources = ["arn:aws:s3:::${local.backup_bucket}"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "modules/s3-backups" ? [1] : []

    content {
      sid    = "ReadBackupIamUser"
      effect = "Allow"
      actions = [
        "iam:GetUser",
        "iam:ListAccessKeys",
        "iam:ListAttachedUserPolicies",
      ]
      resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${local.backup_iam_user}"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "modules/s3-backups" ? [1] : []

    content {
      sid    = "ReadBackupIamPolicy"
      effect = "Allow"
      actions = [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
      ]
      resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.backup_iam_policy}"]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  for_each = local.plan_units

  name        = local.plan_role_names[each.key]
  description = "Role assumed by GitHub Actions to plan ${each.key}"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_plan.json

  tags = {
    ManagedBy = "Terraform"
    Unit      = replace(trimprefix(each.key, "modules/"), "/", "-")
  }
}

# Inline rather than a managed policy per role: each document is attached to
# exactly one role and dies with it, so there is nothing to reuse and nothing to
# leave behind when a unit is removed.
resource "aws_iam_role_policy" "terraform_plan" {
  for_each = local.plan_units

  name   = local.plan_role_names[each.key]
  role   = aws_iam_role.terraform_plan[each.key].id
  policy = data.aws_iam_policy_document.terraform_plan[each.key].json
}

# ---------------------------------------------------------------------------
# Bootstrap plan role: a reviewable plan for the trust anchor itself.
#
# bootstrap/ is plain OpenTofu, applied by hand and never by CI - that is what
# keeps the trust anchor out of a job that runs contributor-supplied HCL. The
# cost is that a change to a trust policy, a role or the state bucket used to be
# reviewed by eye alone. This role buys the plan back: it reads the bootstrap
# state and the resources declared below, and writes only that state's lock
# file. It cannot create, change or delete anything, and it deliberately carries
# no unit credentials - `tofu plan` against bootstrap/ needs no tailnet node, no
# kubeconfig and no provider tokens.
#
# deploy.yaml assumes `terraform-plan-bootstrap`, which is the same family name
# the unit plan roles use, so the workflow needs no additional variable.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "terraform_plan_bootstrap" {
  statement {
    sid       = "ReadBootstrapState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/bootstrap/*"]
  }

  statement {
    sid       = "ReadStateBucketConfig"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  # Same lock semantics as the unit roles: `tofu plan` takes the state lock even
  # though it writes nothing else.
  statement {
    sid       = "StateLockOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/bootstrap/terraform.tfstate.tflock"]
  }

  # The bucket resources in state-bucket.tf: bucket, SSE, versioning and the
  # public access block. Same read set the unit plan roles use for their buckets,
  # plus s3:ListBucket: the aws_s3_bucket read is a HeadBucket, and a 403 there
  # makes the provider conclude the bucket has been deleted - which turns the
  # plan into "create the bucket, replace its three sub-resources" and makes the
  # review comment lie. The unit roles never refresh a bucket resource, so they
  # do not need it.
  statement {
    sid    = "ReadStateBucketResources"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  # Roles and policies are matched by family name rather than by an enumerated
  # list, so a new unit plan role is plannable without editing this policy. The
  # wildcard stops at `terraform-`: no other role or policy is readable.
  statement {
    sid    = "ReadManagedRoles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-*"]
  }

  statement {
    sid    = "ReadManagedPolicies"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/terraform-*"]
  }

  statement {
    sid       = "ReadOidcProvider"
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = [aws_iam_openid_connect_provider.github_actions.arn]
  }
}

resource "aws_iam_role" "terraform_plan_bootstrap" {
  name        = "terraform-plan-bootstrap"
  description = "Role assumed by GitHub Actions to plan bootstrap/ (read-only, plus its state lock)"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_plan.json

  tags = {
    ManagedBy = "Terraform"
    Unit      = "bootstrap"
  }
}

resource "aws_iam_role_policy" "terraform_plan_bootstrap" {
  name   = "terraform-plan-bootstrap"
  role   = aws_iam_role.terraform_plan_bootstrap.id
  policy = data.aws_iam_policy_document.terraform_plan_bootstrap.json
}
