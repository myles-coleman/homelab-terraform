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

# Plan role, used by the plan job on pull requests and on `main`. The workflow
# additionally refuses to request AWS credentials for pull requests from forks
# (.github/workflows/deploy.yaml), because a fork's Terragrunt configuration is
# attacker-controlled and this role can read Terraform state.
data "aws_iam_policy_document" "github_actions_assume_plan" {
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
        "repo:myles-coleman@44505855/homelab-terraform@1329076037:pull_request",
        "repo:myles-coleman@44505855/homelab-terraform@1329076037:ref:refs/heads/main",
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
# Plan role: everything the plan job needs to read state and diff the modules,
# with no write access outside the state lock. Kept separate from the apply role
# so a plan run never holds AdministratorAccess.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "terraform_plan" {
  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  # `use_lockfile = true` in root.hcl makes OpenTofu take a lock by writing
  # `<key>.tflock` and delete it on release. This is the only write the plan
  # role gets, and only under that suffix.
  statement {
    sid       = "StateLockOnly"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*.tflock"]
  }

  # modules/s3-backups plans against this bucket and its IAM user. Keep the name
  # in sync with bucket_name in modules/s3-backups/terragrunt.hcl.
  statement {
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
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = ["arn:aws:s3:::myles-homelab-backups"]
  }

  statement {
    sid    = "ReadBackupIam"
    effect = "Allow"
    actions = [
      "iam:GetAccessKeyLastUsed",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetUser",
      "iam:GetUserPolicy",
      "iam:ListAccessKeys",
      "iam:ListAttachedUserPolicies",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:ListUserPolicies",
      "iam:ListUsers",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_plan" {
  name        = "terraform-plan-read"
  description = "Read-only access for GitHub Actions Terraform plan runs, plus the state lock"
  policy      = data.aws_iam_policy_document.terraform_plan.json

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "terraform_plan" {
  name               = "terraform-plan"
  description        = "Role assumed by GitHub Actions to plan Terraform changes"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_plan.json

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_plan" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = aws_iam_policy.terraform_plan.arn
}
