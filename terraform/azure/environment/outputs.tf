output "resource_group_name" {
  description = "Name of the workload resource group"
  value       = azurerm_resource_group.workload.name
}

output "resource_group_id" {
  description = "ID of the workload resource group"
  value       = azurerm_resource_group.workload.id
}

output "managed_identity_id" {
  description = "ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.id
}

output "managed_identity_client_id" {
  description = "Client ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the workload managed identity"
  value       = azurerm_user_assigned_identity.workload.principal_id
}

output "subnet_compute_id" {
  description = "ID of the compute subnet available to this environment"
  value       = data.azurerm_subnet.compute.id
}

output "environment_name" {
  description = "Environment name"
  value       = var.environment_name
}

output "environment_tier" {
  description = "Environment tier"
  value       = var.environment_tier
}
