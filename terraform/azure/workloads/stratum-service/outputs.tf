output "resource_group_name" {
  description = "Resource group for the workload"
  value       = module.environment.resource_group_name
}

output "managed_identity_client_id" {
  description = "Client ID of the workload managed identity"
  value       = module.environment.managed_identity_client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the workload managed identity"
  value       = module.environment.managed_identity_principal_id
}

output "subnet_compute_id" {
  description = "Compute subnet available to the workload"
  value       = module.environment.subnet_compute_id
}
