# Resource Group voor storage
resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.project_name}-storage"
  location = var.location
  tags     = var.tags
}

# Storage Account voor diagnostics en files
resource "azurerm_storage_account" "main" {
  name                     = "stfonteynfiles${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Random string voor unieke storage account naam
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Storage Account voor boot diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stfonteyndiag${random_string.diag_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = var.tags
}

# Random string voor diagnostics storage
resource "random_string" "diag_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Azure Files Share voor gedeelde bestanden
resource "azurerm_storage_share" "main" {
  name                 = "fonteyn-shared-files"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100 # GB
}

# SQL Server (vervangen door Storage Table voor student account)
# resource "azurerm_mssql_server" "main" {
#   name                         = "sql-${var.project_name}-${random_string.sql_suffix.result}"
#   resource_group_name          = azurerm_resource_group.storage.name
#   location                     = azurerm_resource_group.storage.location
#   version                      = "12.0"
#   administrator_login          = var.sql_admin_username
#   administrator_login_password = var.sql_admin_password
#
#   tags = var.tags
# }

# Random string voor SQL server naam
resource "random_string" "sql_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Storage Table als database alternatief (voor student accounts)
resource "azurerm_storage_table" "main" {
  name                 = "fonteydata"
  storage_account_name = azurerm_storage_account.main.name
}

# SQL Database (vervangen door Storage Table)
# resource "azurerm_mssql_database" "main" {
#   name           = "fonteyn-db"
#   server_id      = azurerm_mssql_server.main.id
#   collation      = "SQL_Latin1_General_CP1_CI_AS"
#   license_type   = "LicenseIncluded"
#   sku_name       = "S1"
#   zone_redundant = false
#
#   tags = var.tags
# }

# Firewall rules zijn niet nodig voor Storage Tables
# resource "azurerm_mssql_firewall_rule" "azure_services" {
#   name             = "AllowAzureServices"
#   server_id        = azurerm_mssql_server.main.id
#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "0.0.0.0"
# }

# resource "azurerm_mssql_firewall_rule" "vnet_access" {
#   name             = "AllowVNetAccess"
#   server_id        = azurerm_mssql_server.main.id
#   start_ip_address = var.vnet_address_start
#   end_ip_address   = var.vnet_address_end
# }

# Backup retention policy (niet nodig voor Storage Tables)
# resource "azurerm_mssql_database_extended_auditing_policy" "main" {
#   database_id            = azurerm_mssql_database.main.id
#   storage_endpoint       = azurerm_storage_account.main.primary_blob_endpoint
#   storage_account_access_key = azurerm_storage_account.main.primary_access_key
#   retention_in_days      = 30
# }