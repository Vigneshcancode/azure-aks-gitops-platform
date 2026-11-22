resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_container_registry" "this" {
  name                = "acr${replace(var.name, "-", "")}${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}

# Explicit push permission for the pipeline identity (no admin user, no passwords).
resource "azurerm_role_assignment" "pipeline_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = var.pipeline_principal_id
}
