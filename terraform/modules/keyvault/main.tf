resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "this" {
  name                       = "kv-${var.name}-${random_string.suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# The pipeline identity needs data-plane rights to create the demo secret.
resource "azurerm_role_assignment" "pipeline_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.pipeline_principal_id
}

resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  depends_on = [azurerm_role_assignment.pipeline_secrets_officer]
}

resource "random_password" "demo" {
  length  = 24
  special = false
}

resource "azurerm_key_vault_secret" "demo" {
  name         = var.secret_name
  value        = random_password.demo.result
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [time_sleep.wait_for_rbac]
}

# Identity the pod uses to read the secret (Entra Workload Identity).
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.name}-hello-api"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "app" {
  name                = "fic-hello-api"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
}

resource "azurerm_role_assignment" "app_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}
