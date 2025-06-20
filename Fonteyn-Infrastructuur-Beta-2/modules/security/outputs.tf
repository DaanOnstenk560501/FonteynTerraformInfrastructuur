output "security_resource_group_name" {
  value = azurerm_resource_group.security.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.vm_identity.id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.vm_identity.principal_id
}

output "recovery_vault_name" {
  value = azurerm_recovery_services_vault.main.name
}

output "backup_policy_id" {
  value = azurerm_backup_policy_vm.main.id
}