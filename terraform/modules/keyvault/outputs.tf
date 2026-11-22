output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "app_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}

output "secret_name" {
  value = azurerm_key_vault_secret.demo.name
}
