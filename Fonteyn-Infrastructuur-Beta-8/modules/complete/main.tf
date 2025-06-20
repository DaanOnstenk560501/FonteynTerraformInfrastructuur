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
  features {}
}

locals {
  vm_size_standard    = "Standard_B1s" # Change from B2s to B1s (1 core)
  vm_size_workstation = "Standard_B1s" # Change from B2s to B1s (1 core)
  storage_type        = var.environment == "production" ? "Premium_LRS" : "Standard_LRS"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Company     = "Fonteyn"
    ManagedBy   = "terraform"
  }
}

resource "random_password" "admin_password" {
  length      = 16
  special     = true
  numeric     = true
  upper       = true
  lower       = true
  min_special = 2
  min_numeric = 2
  min_upper   = 2
  min_lower   = 2
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# General purpose random suffix (could be used for VM names if needed, or left as is)
resource "random_id" "general_suffix" {
  byte_length = 8 # Keeps this longer for general uniqueness needs like VM names if necessary
}

# --- NEW: Shorter random suffix for Storage Accounts and Key Vaults ---
resource "random_id" "short_suffix" {
  byte_length = 2 # Generates 4 hex characters (e.g., "abcd"). Ensures length compliance.
}

resource "azurerm_storage_account" "diagnostics" {
  # --- Use short_suffix and ensure name is within 24 characters and only lowercase/numbers ---
  name                 = "stdiag${var.project_name}${random_id.short_suffix.hex}"
  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  account_tier         = "Standard"
  account_replication_type = "LRS"
  tags                 = local.common_tags
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  # --- Use short_suffix and ensure name is within 24 characters and alphanumeric/dashes ---
  # For Key Vault, we'll keep the dashes but ensure the total length is good.
  # The combined length of "kv-fonteyn-" (11 chars) + 4 chars from short_suffix.hex = 15 chars (within 24)
  name                = "kv-${var.project_name}-${random_id.short_suffix.hex}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete"]
  }
  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "admin-password"
  value        = random_password.admin_password.result
  key_vault_id = azurerm_key_vault.main.id
}

# DevTest Lab Auto-Shutdown Schedule for all VMs
locals {
  # Dynamically collect IDs of VMs created by this config in the 'servers' block
  # This will now correctly include "appserver", "database", and "fileserver"
  created_server_vm_ids = {
    for k, v in azurerm_windows_virtual_machine.servers : k => v.id
  }

  # Merge with the workstation VM ID.
  # This correctly results in 4 VMs total for the shutdown schedule:
  # - "appserver" (newly created server)
  # - "database" (newly created server)
  # - "fileserver" (newly created server)
  # - "workstation" (newly created workstation)
  all_vm_ids = merge(
    local.created_server_vm_ids,
    {
      "workstation" = azurerm_windows_virtual_machine.workstation.id
    }
  )
}

# --- REMOVED: data "azurerm_windows_virtual_machine" "existing_appserver" ---
# The appserver is now being created by this configuration.

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vms_shutdown" {
  for_each              = local.all_vm_ids
  virtual_machine_id    = each.value
  location              = var.location
  enabled               = var.enable_vm_shutdown_schedule
  daily_recurrence_time = var.vm_shutdown_time
  timezone              = var.vm_shutdown_timezone

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}