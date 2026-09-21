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

data "aws_iam_policy_document" "github_actions_assume_role" {
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
      values = [
        # homelab-terraform was created after 2026-07-15, so GitHub issues an
        # immutable subject claim that includes the owner and repository IDs:
        #   repo:OWNER@OWNER-ID/REPO@REPO-ID:*
        "repo:myles-coleman@44505855/homelab-terraform@1329076037:*",
        # homelab-cluster predates 2026-07-15 and uses the classic subject
        # format. Keep it trusted until the migration off homelab-cluster is
        # complete, then remove this line.
        "repo:myles-coleman/homelab-cluster:*",
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
  description        = "Role assumed by GitHub Actions for Terraform operations with administrative access"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

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
