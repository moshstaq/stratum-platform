# ── Azure Platform Outputs ────────────────────────────────────────────────────
# These values are consumed by stratum-platform workload modules.
# Resource IDs are never hardcoded — always resolved via data sources.

output "rg_workloads_name" {
  description = "Name of the workloads resource group"
  value       = data.azurerm_resource_group.workloads.name
}

output "rg_taskflow_name" {
  description = "Name of the taskflow landing zone resource group"
  value       = data.azurerm_resource_group.taskflow.name
}

output "vnet_hub_id" {
  description = "ID of the hub VNet"
  value       = data.azurerm_virtual_network.hub.id
}

output "vnet_workloads_id" {
  description = "ID of the workloads spoke VNet"
  value       = data.azurerm_virtual_network.workloads.id
}

output "snet_aks_id" {
  description = "ID of the AKS subnet"
  value       = data.azurerm_subnet.aks.id
}

output "snet_containers_id" {
  description = "ID of the containers subnet"
  value       = data.azurerm_subnet.containers.id
}

output "snet_compute_id" {
  description = "ID of the compute subnet"
  value       = data.azurerm_subnet.compute.id
}

output "law_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = data.azurerm_log_analytics_workspace.platform.id
}

output "action_group_id" {
  description = "ID of the platform alerts action group"
  value       = data.azurerm_monitor_action_group.platform.id
}
