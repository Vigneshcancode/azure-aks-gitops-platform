output "resource_group_name" {
  value = module.platform.resource_group_name
}

output "aks_name" {
  value = module.platform.aks_name
}

output "acr_login_server" {
  value = module.platform.acr_login_server
}

output "key_vault_name" {
  value = module.platform.key_vault_name
}

output "app_identity_client_id" {
  value = module.platform.app_identity_client_id
}

output "tenant_id" {
  value = module.platform.tenant_id
}
