# main.tf - Core Infrastructure for Fonteyn Windows Hybrid Environment
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
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Common tags for all resources
locals {
  common_tags = {
    Project      = var.project_name
    Environment  = var.environment
    OS           = "Windows Server 2022"
    ManagedBy    = "terraform"
    Company      = "Fonteyn"
    Architecture = "hybrid-3tier"
    Domain       = "fonteyn.corp"
    Location     = var.location
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Generate secure admin password
resource "random_password" "admin_password" {
  length  = 20
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Main Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}-hybrid"
  location = var.location
  tags     = local.common_tags
}

# Storage Account for VM diagnostics and logs
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = local.common_tags
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.common_tags
}

# Key Vault for storing secrets
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
      "Get", "List", "Set", "Delete", "Backup", "Restore"
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

# Store VPN shared key in Key Vault
resource "azurerm_key_vault_secret" "vpn_shared_key" {
  name         = "vpn-shared-key"
  value        = var.vpn_shared_key
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
  soft_delete_enabled = false
  
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

# Automation Account for Windows maintenance
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