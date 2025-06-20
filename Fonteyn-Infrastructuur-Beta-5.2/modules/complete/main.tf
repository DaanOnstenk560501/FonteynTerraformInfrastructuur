# main.tf - Core Infrastructure for Windows Testing
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Common tags
locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    OS          = "Windows Server 2022"
    ManagedBy   = "terraform"
    CreatedBy   = "testing"
    Architecture = "3-tier"
  }, var.tags)
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Resource Groups
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# Storage for diagnostics and logs
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Enable soft delete for better data protection
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = local.common_tags
}

# Log Analytics for monitoring Windows VMs
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.common_tags
}

# Key Vault for storing sensitive information
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project_name}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Backup",
      "Restore"
    ]
  }

  tags = local.common_tags
}

# Store admin password in Key Vault
resource "azurerm_key_vault_secret" "admin_password" {
  name         = "vm-admin-password"
  value        = random_password.admin_password.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = local.common_tags
}

# Recovery Services Vault for backups (optional)
resource "azurerm_recovery_services_vault" "main" {
  count               = var.enable_backup ? 1 : 0
  name                = "rsv-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  soft_delete_enabled = false  # Disabled for testing environments
  
  tags = local.common_tags
}

# Backup policy for VMs
resource "azurerm_backup_policy_vm" "main" {
  count               = var.enable_backup ? 1 : 0
  name                = "backup-policy-vms"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }
}

# Network Watcher - Azure creates one automatically per region
# Use existing Network Watcher instead of creating a new one
data "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${lower(replace(var.location, " ", ""))}"
  resource_group_name = "NetworkWatcherRG"
}

# Windows-specific automation account for maintenance
resource "azurerm_automation_account" "main" {
  name                = "aa-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Basic"
  
  tags = local.common_tags
}

# Application Insights for monitoring web applications
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  tags = local.common_tags
}