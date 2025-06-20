# ========================================
# SECURITY MODULE
# ========================================

# modules/security/main.tf
# Data source voor huidige gebruiker
data "azurerm_client_config" "current" {}

# Resource Group voor security
resource "azurerm_resource_group" "security" {
  name     = "rg-${var.project_name}-security"
  location = var.location
  tags     = merge(var.tags, {
    Purpose = "Security-Compliance"
  })
}

# Key Vault voor geheimen (verbeterd)
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project_name}-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium" # Premium voor HSM-backed keys
  
  # Productie-waardige instellingen
  purge_protection_enabled   = var.environment == "prod" ? true : false
  soft_delete_retention_days = 30
  
  # Strikte netwerk toegang
  network_acls {
    default_action = var.environment == "prod" ? "Deny" : "Allow"
    bypass         = "AzureServices"
    
    # Alleen specifieke IP ranges toestaan in productie
    ip_rules = var.allowed_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
  
  # Logging en monitoring
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  
  tags = merge(var.tags, {
    SecurityLevel = "Critical"
    Compliance    = "GDPR"
  })
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
    "Create", "Get", "List", "Update", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]

  secret_permissions = [
    "Set", "Get", "List", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]

  certificate_permissions = [
    "Create", "Get", "List", "Update", "Delete", "ManageContacts", "Import"
  ]
}

# Azure AD Integration - Conditional Access Policy
resource "azuread_conditional_access_policy" "mfa_policy" {
  display_name = "Require MFA for Administrators - ${var.project_name}"
  state        = var.environment == "prod" ? "enabled" : "enabledForReportingButNotEnforced"

  conditions {
    users {
      included_groups = [var.admin_group_id]
    }
    
    applications {
      included_applications = ["All"]
    }
    
    locations {
      included_locations = ["All"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }

  session_controls {
    sign_in_frequency {
      value = 4
      type  = "hours"
    }
  }
}

# Network Security Group voor VMs
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-${var.project_name}-vm"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name

  # Alleen HTTPS en SSH toegestaan
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_ip_ranges
    destination_address_prefix = "*"
  }

  # Deny alle andere inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Azure Security Center (Defender for Cloud)
resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = var.enable_defender ? "Standard" : "Free"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = var.enable_defender ? "Standard" : "Free"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = var.enable_defender ? "Standard" : "Free"
  resource_type = "StorageAccounts"
}

# Log Analytics Workspace voor security monitoring
resource "azurerm_log_analytics_workspace" "security" {
  name                = "law-${var.project_name}-security"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = merge(var.tags, {
    Purpose = "SecurityMonitoring"
  })
}

# Security monitoring solutions
resource "azurerm_log_analytics_solution" "security" {
  solution_name         = "Security"
  location              = azurerm_resource_group.security.location
  resource_group_name   = azurerm_resource_group.security.name
  workspace_resource_id = azurerm_log_analytics_workspace.security.id
  workspace_name        = azurerm_log_analytics_workspace.security.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }
}

# Azure Monitor Action Group voor security alerts
resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "ag-${var.project_name}-security"
  resource_group_name = azurerm_resource_group.security.name
  short_name          = "SecAlert"

  email_receiver {
    name          = "Security Team"
    email_address = var.security_alert_email
  }

  dynamic "sms_receiver" {
    for_each = var.security_alert_phone != "" ? [1] : []
    content {
      name         = "Security SMS"
      country_code = "31" # Nederland
      phone_number = var.security_alert_phone
    }
  }

  tags = var.tags
}

# Key Vault diagnostic logging
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name               = "diag-${azurerm_key_vault.main.name}"
  target_resource_id = azurerm_key_vault.main.id
  
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Store secrets in Key Vault (verbeterd)
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  
  # Automatische rotatie
  expiration_date = timeadd(timestamp(), "8760h") # 1 jaar

  depends_on = [azurerm_key_vault_access_policy.current_user]

  lifecycle {
    ignore_changes = [value] # Voorkom dat Terraform het wachtwoord overschrijft
  }

  tags = merge(var.tags, {
    SecretType = "DatabaseCredential"
  })
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  value        = var.storage_account_key
  key_vault_id = azurerm_key_vault.main.id
  
  expiration_date = timeadd(timestamp(), "8760h")

  depends_on = [azurerm_key_vault_access_policy.current_user]

  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.tags, {
    SecretType = "StorageKey"
  })
}

# Encryption key voor disk encryption
resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_key_vault_access_policy.current_user]

  tags = var.tags
}

# User Assigned Managed Identity voor VMs
resource "azurerm_user_assigned_identity" "vm_identity" {
  name                = "id-${var.project_name}-vm"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name

  tags = merge(var.tags, {
    Purpose = "VMIdentity"
  })
}

# Access policy voor VM Managed Identity
resource "azurerm_key_vault_access_policy" "vm_identity" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.vm_identity.principal_id

  secret_permissions = [
    "Get", "List"
  ]
  
  key_permissions = [
    "Get", "List", "Decrypt", "Encrypt"
  ]
}

# Recovery Services Vault (verbeterd voor geo-redundantie)
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  
  # Cross Region Restore voor extra bescherming
  cross_region_restore_enabled = true

  tags = merge(var.tags, {
    Purpose = "BackupAndRecovery"
  })
}

# Verbeterde backup policy voor VMs
resource "azurerm_backup_policy_vm" "main" {
  name                = "bp-${var.project_name}-vm"
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  resource_group_name = azurerm_resource_group.security.name
  
  # Timezone instelling
  timezone = "W. Europe Standard Time"

  backup {
    frequency = "Daily"
    time      = "02:00"
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
  
  retention_yearly {
    count    = 7
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
}

# Policy voor automatische restore-tests
resource "azurerm_backup_policy_vm" "test_restore" {
  name                = "bp-${var.project_name}-test-restore"
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  resource_group_name = azurerm_resource_group.security.name

  backup {
    frequency = "Weekly"
    time      = "03:00"
    weekdays  = ["Saturday"]
  }

  retention_weekly {
    count    = 4
    weekdays = ["Saturday"]
  }
}

# DDoS Protection Plan (optioneel voor productie)
resource "azurerm_network_ddos_protection_plan" "main" {
  count = var.enable_ddos_protection ? 1 : 0
  
  name                = "ddos-${var.project_name}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name

  tags = var.tags
}

# modules/security/outputs.tf
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

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.security.id
}

output "vm_nsg_id" {
  value = azurerm_network_security_group.vm_nsg.id
}

output "disk_encryption_key_id" {
  value = azurerm_key_vault_key.disk_encryption.id
}

output "security_action_group_id" {
  value = azurerm_monitor_action_group.security_alerts.id
}

# modules/security/variables.tf
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
  default     = "dev"
}

variable "sql_admin_password" {
  description = "SQL Server admin wachtwoord"
  type        = string
  sensitive   = true
}

variable "storage_account_key" {
  description = "Storage account access key"
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

variable "admin_group_id" {
  description = "Azure AD groep ID voor beheerders (voor Conditional Access)"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "IP ranges die toegang hebben tot Key Vault"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs die toegang hebben tot Key Vault"
  type        = list(string)
  default     = []
}

variable "admin_ip_ranges" {
  description = "IP ranges voor beheerders SSH/RDP toegang"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "security_alert_email" {
  description = "Email adres voor security alerts"
  type        = string
}

variable "security_alert_phone" {
  description = "Telefoonnummer voor kritieke security alerts"
  type        = string
  default     = ""
}

variable "enable_defender" {
  description = "Azure Defender inschakelen (Standard tier)"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "DDoS Protection Plan inschakelen"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention (dagen)"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}