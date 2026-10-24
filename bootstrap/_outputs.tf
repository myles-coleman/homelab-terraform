output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "terraform_role_arn" {
  description = "ARN of the Terraform operations IAM role"
  value       = aws_iam_role.terraform_operations.arn
}

output "terraform_plan_role_arns" {
  description = "ARN of the read-only plan role for each unit, keyed by its plan role name (unit path without `modules/`, `/` flattened to `-`)"
  value       = { for unit, role in aws_iam_role.terraform_plan : trimprefix(local.plan_role_names[unit], "terraform-plan-") => role.arn }
}

output "terraform_plan_role_family" {
  description = "Family prefix of the per-unit plan roles; AWS_PLAN_ROLE_ARN holds `<this>` and deploy.yaml appends `-<unit slug>`"
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-plan"
}
