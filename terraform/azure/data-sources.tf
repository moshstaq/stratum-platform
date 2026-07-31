# ── Azure Landing Zone — Data Contracts ───────────────────────────────────────
# Discovers upstream platform boundaries from azure-landing-zone.
# No terraform_remote_state — data sources only per ADR-001.
# stratum-platform is a public repository. Remote state would expose
# sensitive landing zone outputs to anyone reading the configuration.

# ── Resource Groups ───────────────────────────────────────────────────────────

data "azurerm_resource_group" "connectivity" {
  name = "rg-platform-connectivity"
}

data "azurerm_resource_group" "management" {
  name = "rg-platform-management"
}

data "azurerm_resource_group" "workloads" {
  name = "rg-workloads"
}

data "azurerm_resource_group" "taskflow" {
  name = "rg-taskflow"
}

# ── Networking ────────────────────────────────────────────────────────────────

data "azurerm_virtual_network" "hub" {
  name                = "vnet-hub"
  resource_group_name = data.azurerm_resource_group.connectivity.name
}

data "azurerm_virtual_network" "workloads" {
  name                = "vnet-workloads"
  resource_group_name = data.azurerm_resource_group.workloads.name
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  virtual_network_name = data.azurerm_virtual_network.workloads.name
  resource_group_name  = data.azurerm_resource_group.workloads.name
}

data "azurerm_subnet" "containers" {
  name                 = "snet-containers"
  virtual_network_name = data.azurerm_virtual_network.workloads.name
  resource_group_name  = data.azurerm_resource_group.workloads.name
}

data "azurerm_subnet" "compute" {
  name                 = "snet-compute"
  virtual_network_name = data.azurerm_virtual_network.workloads.name
  resource_group_name  = data.azurerm_resource_group.workloads.name
}

# ── Observability ─────────────────────────────────────────────────────────────

data "azurerm_log_analytics_workspace" "platform" {
  name                = "law-platform"
  resource_group_name = data.azurerm_resource_group.management.name
}

data "azurerm_monitor_action_group" "platform" {
  name                = "ag-platform-alerts"
  resource_group_name = data.azurerm_resource_group.management.name
}
