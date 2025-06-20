# ==============================================================================
# STORAGE MODULE OUTPUTS (COMPLETE & FIXED)
# ==============================================================================

output "storage_resource_group_name" {
  description = "Storage resource group naam"
  value       = azurerm_resource_group.storage.name
}

# ==============================================================================
# STORAGE ACCOUNT OUTPUTS
# ==============================================================================

output "storage_account_name" {
  description = "Main storage account naam"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "Main storage account ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_primary_access_key" {
  description = "Storage account primary access key"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "storage_account_primary_connection_string" {
  description = "Storage account primary connection string"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

# Diagnostics storage
output "diagnostics_storage_account_name" {
  description = "Diagnostics storage account naam"
  value       = azurerm_storage_account.diagnostics.name
}

output "diagnostics_storage_account_uri" {
  description = "Diagnostics storage account URI voor boot diagnostics"
  value       = azurerm_storage_account.diagnostics.primary_blob_endpoint
}

# ==============================================================================
# PREMIUM FILES OUTPUTS
# ==============================================================================

output "premium_storage_account_name" {
  description = "Premium storage account naam"
  value       = azurerm_storage_account.premium_files.name
}

output "premium_files_share_name" {
  description = "Premium files share naam"
  value       = azurerm_storage_share.premium_shared.name
}

output "premium_files_share_url" {
  description = "Premium files share URL"
  value       = azurerm_storage_share.premium_shared.url
}

# FIXED: This was referenced in main.tf but didn't exist
output "files_share_url" {
  description = "Files share URL (alias for premium_files_share_url)"
  value       = azurerm_storage_share.premium_shared.url
}

# ==============================================================================
# SQL SERVER OUTPUTS
# ==============================================================================

output "sql_server_name" {
  description = "SQL Server naam"
  value       = azurerm_mssql_server.main.name
}

output "sql_server_id" {
  description = "SQL Server ID"
  value       = azurerm_mssql_server.main.id
}

output "sql_server_fqdn" {
  description = "SQL Server FQDN"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "SQL Database naam"
  value       = azurerm_mssql_database.booking_system.name
}

output "sql_database_id" {
  description = "SQL Database ID"
  value       = azurerm_mssql_database.booking_system.id
}

# Failover group outputs
output "sql_failover_group_name" {
  description = "SQL Failover Group naam"
  value       = azurerm_mssql_failover_group.main.name
}

output "sql_failover_group_id" {
  description = "SQL Failover Group ID"
  value       = azurerm_mssql_failover_group.main.id
}

# ==============================================================================
# BACKUP OUTPUTS
# ==============================================================================

output "backup_vault_id" {
  description = "Backup Vault ID"
  value       = azurerm_data_protection_backup_vault.main.id
}

output "backup_vault_name" {
  description = "Backup Vault naam"
  value       = azurerm_data_protection_backup_vault.main.name
}

# ==============================================================================
# CONNECTION STRINGS & ENDPOINTS
# ==============================================================================

output "sql_connection_string" {
  description = "SQL Database connection string"
  value       = "Server=${azurerm_mssql_server.main.fully_qualified_domain_name};Database=${azurerm_mssql_database.booking_system.name};Authentication=Active Directory Default;"
  sensitive   = false
}

output "storage_endpoints" {
  description = "Storage account endpoints"
  value = {
    blob  = azurerm_storage_account.main.primary_blob_endpoint
    file  = azurerm_storage_account.main.primary_file_endpoint
    table = azurerm_storage_account.main.primary_table_endpoint
    queue = azurerm_storage_account.main.primary_queue_endpoint
  }
}