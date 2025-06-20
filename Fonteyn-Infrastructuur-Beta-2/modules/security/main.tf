# Data source voor huidige gebruiker
data "azurerm_client_config" "current" {}

# Resource Group voor security
resource "azurerm_resource_group" "security" {
  name     = "rg-${var.project_name}-security"
  location = var.location
  tags     = var.tags
}

# Key Vault voor geheimen
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project_name}-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Purge protection voor productie
  purge_protection_enabled = false # Voor dev/test omgeving

  # Network access
  network_acls {
    default_action = "Allow" # Voor dev - in productie zou dit "Deny" zijn
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# Random string voor Key Vault naam
resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Access policy voor de huidige gebruiker
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Get",
    "List",
    "Update",
    "Delete",
  ]

  secret_permissions = [
    "Set",
    "Get",
    "List",
    "Delete",
  ]

  certificate_permissions = [
    "Create",
    "Get",
    "List",
    "Update",
    "Delete",
  ]
}

# Store SQL admin password in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  tags = var.tags
}

# Store storage account key in Key Vault
resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  value        = var.storage_account_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  tags = var.tags
}

# User Assigned Managed Identity voor VMs
resource "azurerm_user_assigned_identity" "vm_identity" {
  name                = "id-${var.project_name}-vm"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name

  tags = var.tags
}

# Access policy voor VM Managed Identity
resource "azurerm_key_vault_access_policy" "vm_identity" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.vm_identity.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Recovery Services Vault voor backups
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  sku                 = "Standard"

  tags = var.tags
}

# Backup policy voor VMs
resource "azurerm_backup_policy_vm" "main" {
  name                = "bp-${var.project_name}-vm"
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  resource_group_name = azurerm_resource_group.security.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}