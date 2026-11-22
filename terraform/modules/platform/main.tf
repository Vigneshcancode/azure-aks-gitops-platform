data "azurerm_client_config" "current" {}

locals {
  name = "${var.project}-${var.environment}"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# Governance: block resources outside the approved region inside this resource group.
data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations (${var.location} only)"
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [var.location]
    }
  })
}

module "network" {
  source = "../network"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  tags                = local.tags
}

module "monitoring" {
  source = "../monitoring"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

module "acr" {
  source = "../acr"

  name                  = local.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  pipeline_principal_id = data.azurerm_client_config.current.object_id
  tags                  = local.tags
}

module "aks" {
  source = "../aks"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  subnet_id                  = module.network.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  acr_id                     = module.acr.id
  sku_tier                   = var.aks_sku_tier
  node_vm_size               = var.node_vm_size
  node_count                 = var.node_count
  user_node_count            = var.user_node_count
  tags                       = local.tags
}

module "keyvault" {
  source = "../keyvault"

  name                  = local.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.this.name
  tenant_id             = data.azurerm_client_config.current.tenant_id
  pipeline_principal_id = data.azurerm_client_config.current.object_id
  aks_oidc_issuer_url   = module.aks.oidc_issuer_url
  tags                  = local.tags
}

module "alerts" {
  source = "../alerts"

  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
  aks_id              = module.aks.id
  alert_email         = var.alert_email
  tags                = local.tags
}
