output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_name" {
  value = module.aks.name
}

output "acr_name" {
  value = module.acr.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_name" {
  value = module.keyvault.key_vault_name
}

output "app_identity_client_id" {
  value = module.keyvault.app_identity_client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "log_analytics_workspace_name" {
  value = module.monitoring.workspace_name
}
