# ==============================================================================
# SECURITY MODULE OUTPUTS (COMPLETE & FIXED)
# ==============================================================================

output "security_resource_group_name" {
  description = "Security resource group naam"
  value       = azurerm_resource_group.security.name
}

output "key_vault_name" {
  description = "Key Vault naam"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.main.id
}

# ==============================================================================
# MANAGED IDENTITY OUTPUTS
# ==============================================================================

output "managed_identity_id" {
  description = "User assigned managed identity ID"
  value       = azurerm_user_assigned_identity.vm_identity.id
}

output "managed_identity_principal_id" {
  description = "User assigned managed identity principal ID"
  value       = azurerm_user_assigned_identity.vm_identity.principal_id
}

output "managed_identity_client_id" {
  description = "User assigned managed identity client ID"
  value       = azurerm_user_assigned_identity.vm_identity.client_id
}

# ==============================================================================
# BACKUP & RECOVERY OUTPUTS
# ==============================================================================

output "recovery_vault_name" {
  description = "Recovery Services Vault naam"
  value       = azurerm_recovery_services_vault.main.name
}

output "recovery_vault_id" {
  description = "Recovery Services Vault ID"
  value       = azurerm_recovery_services_vault.main.id
}

output "backup_policy_id" {
  description = "VM backup policy ID"
  value       = azurerm_backup_policy_vm.main.id
}

# ==============================================================================
# MONITORING OUTPUTS
# ==============================================================================

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.security.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace naam"
  value       = azurerm_log_analytics_workspace.security.name
}

output "security_action_group_id" {
  description = "Security Action Group ID"
  value       = azurerm_monitor_action_group.security_alerts.id
}

# ==============================================================================
# ENCRYPTION OUTPUTS
# ==============================================================================

output "disk_encryption_key_id" {
  description = "Disk encryption key ID"
  value       = azurerm_key_vault_key.disk_encryption.id
}

output "disk_encryption_key_vault_uri" {
  description = "Key Vault URI for disk encryption"
  value       = azurerm_key_vault.main.vault_uri
}

# ==============================================================================
# NETWORK SECURITY OUTPUTS
# ==============================================================================

output "vm_nsg_id" {
  description = "VM Network Security Group ID"
  value       = azurerm_network_security_group.vm_nsg.id
}

# ==============================================================================
# DDOS PROTECTION OUTPUTS (CONDITIONAL)
# ==============================================================================

output "ddos_protection_plan_id" {
  description = "DDoS Protection Plan ID (null if disabled)"
  value       = var.enable_ddos_protection ? azurerm_network_ddos_protection_plan.main[0].id : null
}