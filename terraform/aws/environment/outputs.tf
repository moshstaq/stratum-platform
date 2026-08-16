output "workload_role_arn" {
  description = "ARN of the workload IAM role"
  value       = aws_iam_role.workload.arn
}

output "workload_security_group_id" {
  description = "ID of the workload security group"
  value       = aws_security_group.workload.id
}

output "workload_bucket_name" {
  description = "Name of the workload S3 bucket"
  value       = aws_s3_bucket.workload.bucket
}

output "private_subnet_ids" {
  description = "Private subnet IDs available to this environment"
  value       = data.aws_subnets.private.ids
}

output "vpc_id" {
  description = "VPC ID for this environment"
  value       = data.aws_vpc.platform.id
}

output "environment_name" {
  description = "Environment name"
  value       = var.environment_name
}

output "environment_tier" {
  description = "Environment tier"
  value       = var.environment_tier
}

output "ecr_repository_url" {
  description = "URL of the workload ECR repository"
  value       = aws_ecr_repository.workload.repository_url
}
