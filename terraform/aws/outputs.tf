# ── AWS Platform Outputs ──────────────────────────────────────────────────────
# These values are consumed by stratum-platform workload modules.
# Resource IDs are never hardcoded — always resolved via data sources.

output "vpc_id" {
  description = "ID of the platform VPC"
  value       = data.aws_vpc.platform.id
}

output "vpc_cidr" {
  description = "CIDR block of the platform VPC"
  value       = data.aws_vpc.platform.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = data.aws_subnets.public.ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = data.aws_subnets.private.ids
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = data.aws_ecr_repository.platform.repository_url
}

output "sns_topic_arn" {
  description = "ARN of the platform alerts SNS topic"
  value       = data.aws_sns_topic.platform_alerts.arn
}

output "app_config_secret_arn" {
  description = "ARN of the app config secret"
  value       = data.aws_secretsmanager_secret.app_config.arn
}

