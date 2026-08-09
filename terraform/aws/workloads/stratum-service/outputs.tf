output "workload_role_arn" {
  description = "IAM role ARN for the workload"
  value       = module.environment.workload_role_arn
}

output "workload_bucket_name" {
  description = "S3 bucket for the workload"
  value       = module.environment.workload_bucket_name
}

output "workload_security_group_id" {
  description = "Security group ID for the workload"
  value       = module.environment.workload_security_group_id
}

output "vpc_id" {
  description = "VPC ID for the workload"
  value       = module.environment.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets available to the workload"
  value       = module.environment.private_subnet_ids
}
