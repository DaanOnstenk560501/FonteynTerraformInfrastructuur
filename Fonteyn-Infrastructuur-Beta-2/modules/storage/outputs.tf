output "storage_resource_group_name" {
  value = azurerm_resource_group.storage.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_primary_access_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}

output "diagnostics_storage_account_uri" {
  value = azurerm_storage_account.diagnostics.primary_blob_endpoint
}

output "files_share_name" {
  value = azurerm_storage_share.main.name
}

output "files_share_url" {
  value = azurerm_storage_share.main.url
}

output "storage_table_name" {
  value = azurerm_storage_table.main.name
}

# SQL outputs zijn uitgeschakeld omdat we Storage Table gebruiken
# output "sql_server_name" {
#   value = azurerm_mssql_server.main.name
# }

# output "sql_server_fqdn" {
#   value = azurerm_mssql_server.main.fully_qualified_domain_name
# }

# output "sql_database_name" {
#   value = azurerm_mssql_database.main.name
# }