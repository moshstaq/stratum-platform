# ── Data Contracts ────────────────────────────────────────────────────────────
# Consume platform boundaries from azure-landing-zone via data sources.

data "azurerm_resource_group" "workloads" {
  name = "rg-workloads"
}

data "azurerm_virtual_network" "workloads" {
  name                = "vnet-workloads"
  resource_group_name = data.azurerm_resource_group.workloads.name
}

data "azurerm_subnet" "compute" {
  name                 = "snet-compute"
  virtual_network_name = data.azurerm_virtual_network.workloads.name
  resource_group_name  = data.azurerm_resource_group.workloads.name
}

data "azurerm_log_analytics_workspace" "platform" {
  name                = "law-platform"
  resource_group_name = "rg-platform-management"
}

# ── Local Values ──────────────────────────────────────────────────────────────

locals {
  prefix = "stratum-${var.environment_name}"

  common_tags = {
    Environment = var.environment_name
    Team        = var.team_name
    Tier        = var.environment_tier
    ManagedBy   = "terraform"
    Project     = "stratum"
    Platform    = "azure"
  }
}

# ── Resource Group — Workload Boundary ───────────────────────────────────────
# Each environment gets its own resource group.
# Platform provisions the boundary, workload fills it.
# Same landing zone pattern as rg-taskflow in azure-landing-zone.

resource "azurerm_resource_group" "workload" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.common_tags
}

# ── User Assigned Managed Identity ───────────────────────────────────────────
# Workload identity for this environment.
# Equivalent of the IAM role in the AWS environment module.
# Applications use this identity to access Azure services without
# stored credentials.

resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${local.prefix}"
  resource_group_name = azurerm_resource_group.workload.name
  location            = azurerm_resource_group.workload.location
  tags                = local.common_tags
}

# ── Diagnostic Settings ───────────────────────────────────────────────────────
# Connect workload resource group activity logs to platform
# Log Analytics workspace automatically.
# Developer does not configure observability — platform enforces it.

resource "azurerm_monitor_diagnostic_setting" "workload" {
  name                       = "diag-${local.prefix}"
  target_resource_id         = azurerm_resource_group.workload.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Policy"
  }
}
