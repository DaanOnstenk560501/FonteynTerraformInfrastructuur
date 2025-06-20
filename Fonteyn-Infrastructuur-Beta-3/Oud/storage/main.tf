# ========================================
# STORAGE MODULE
# ========================================

# modules/storage/main.tf
# Resource Group voor storage
resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.project_name}-storage"
  location = var.location
  tags     = merge(var.tags, {
    Environment = var.environment
    CostCenter  = "IT-Infrastructure"
  })
}

# Premium Storage Account voor Azure Files (G-schijf vervanging)
resource "azurerm_storage_account" "premium_files" {
  name                     = "stfonteynprem${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS" # Premium heeft geen GRS optie
  
  tags = merge(var.tags, {
    Purpose = "SharedFiles-GDriveReplacement"
  })
}

# Standard Storage Account met geo-replicatie voor algemene opslag
resource "azurerm_storage_account" "main" {
  name                     = "stfonteynfiles${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundante opslag conform ontwerp
  
  blob_properties {
    delete_retention_policy {
      days = 30 # Verlengd conform backup-strategie
    }
    versioning_enabled = true
  }

  tags = merge(var.tags, {
    Purpose = "GeneralStorage"
  })
}

# Random string voor unieke storage account naam
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Storage Account voor diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stfonteyndiag${random_string.diag_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Diagnostics hoeft niet geo-gerepliceerd
  
  tags = merge(var.tags, {
    Purpose = "Diagnostics"
  })
}

# Random string voor diagnostics storage
resource "random_string" "diag_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Premium Azure Files Share voor G-schijf vervanging
resource "azurerm_storage_share" "premium_shared" {
  name                 = "fonteyn-shared-files"
  storage_account_name = azurerm_storage_account.premium_files.name
  quota                = 500 # GB - verhoogd voor bedrijfsgebruik
  tier                 = "Premium"
}

# SQL Server (hersteld conform technisch ontwerp)
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.project_name}-${random_string.sql_suffix.result}"
  resource_group_name          = azurerm_resource_group.storage.name
  location                     = azurerm_resource_group.storage.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  
  # Azure AD integration
  azuread_administrator {
    login_username = var.sql_azuread_admin_login
    object_id      = var.sql_azuread_admin_object_id
  }

  tags = merge(var.tags, {
    Purpose = "BookingSystem"
  })
}

# Random string voor SQL server naam
resource "random_string" "sql_suffix" {
  length  = 4
  special = false
  upper   = false
}

# SQL Database voor boekingssysteem (conform ontwerp)
resource "azurerm_mssql_database" "booking_system" {
  name           = "fonteyn-booking-db"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S2" # Verhoogd voor productie-workload
  zone_redundant = false
  
  # Geo-replicatie voor disaster recovery
  geo_backup_enabled = true
  
  tags = merge(var.tags, {
    Purpose = "BookingSystem"
    Backup  = "Required"
  })
}

# Geo-replica database (secundaire regio Noord-Europa)
resource "azurerm_mssql_server" "secondary" {
  name                         = "sql-${var.project_name}-sec-${random_string.sql_suffix.result}"
  resource_group_name          = azurerm_resource_group.storage.name
  location                     = var.secondary_location # Noord-Europa
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  tags = merge(var.tags, {
    Purpose = "DisasterRecovery"
  })
}

# Failover group voor automatische failover
resource "azurerm_mssql_failover_group" "main" {
  name      = "fg-${var.project_name}"
  server_id = azurerm_mssql_server.main.id
  
  databases = [
    azurerm_mssql_database.booking_system.id
  ]
  
  partner_server {
    id = azurerm_mssql_server.secondary.id
  }
  
  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60 # 1 uur failover tijd
  }

  tags = var.tags
}

# SQL Firewall rules
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "vnet_access" {
  name             = "AllowVNetAccess"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = var.vnet_address_start
  end_ip_address   = var.vnet_address_end
}

# Backup vault voor Azure Backup
resource "azurerm_data_protection_backup_vault" "main" {
  name                = "bv-${var.project_name}"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  datastore_type      = "VaultStore"
  redundancy         = "GeoRedundant" # Conform AVG-vereisten
  
  tags = merge(var.tags, {
    Purpose = "BackupAndRecovery"
  })
}

# Backup policy voor databases
resource "azurerm_data_protection_backup_policy_blob_storage" "main" {
  name     = "bp-${var.project_name}-storage"
  vault_id = azurerm_data_protection_backup_vault.main.id
  
  retention_duration = "P30D" # 30 dagen retention

  backup_repeating_time_intervals = ["R/2024-01-01T02:00:00+00:00/P1D"] # Dagelijks om 02:00
}

# Cost management budget alert
resource "azurerm_consumption_budget_resource_group" "storage" {
  name              = "budget-${var.project_name}-storage"
  resource_group_id = azurerm_resource_group.storage.id
  
  amount     = var.monthly_budget_limit
  time_grain = "Monthly"
  
  time_period {
    start_date = "2024-01-01T00:00:00Z"
  }
  
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"
    
    contact_emails = var.budget_alert_emails
  }
}

# modules/storage/outputs.tf
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

# Premium files outputs
output "premium_storage_account_name" {
  value = azurerm_storage_account.premium_files.name
}

output "premium_files_share_name" {
  value = azurerm_storage_share.premium_shared.name
}

output "premium_files_share_url" {
  value = azurerm_storage_share.premium_shared.url
}

# SQL outputs
output "sql_server_name" {
  value = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.booking_system.name
}

# Failover group output
output "sql_failover_group_name" {
  value = azurerm_mssql_failover_group.main.name
}

# Backup vault output
output "backup_vault_id" {
  value = azurerm_data_protection_backup_vault.main.id
}

# modules/storage/variables.tf
variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "sql_admin_username" {
  description = "SQL Server admin gebruikersnaam"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server admin wachtwoord"
  type        = string
  sensitive   = true
}

variable "sql_azuread_admin_login" {
  description = "Azure AD admin login naam voor SQL Server"
  type        = string
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID voor SQL Server"
  type        = string
}

variable "vnet_address_start" {
  description = "Start IP van VNet range"
  type        = string
  default     = "10.0.0.0"
}

variable "vnet_address_end" {
  description = "Eind IP van VNet range"
  type        = string
  default     = "10.0.255.255"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "secondary_location" {
  description = "Secundaire Azure locatie (Noord-Europa)"
  type        = string
  default     = "North Europe"
}

variable "monthly_budget_limit" {
  description = "Maandelijks budget limiet in euros"
  type        = number
  default     = 5000
}

variable "budget_alert_emails" {
  description = "Email adressen voor budget alerts"
  type        = list(string)
}