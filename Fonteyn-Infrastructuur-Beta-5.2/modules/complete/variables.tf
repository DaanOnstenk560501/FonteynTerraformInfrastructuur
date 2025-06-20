# variables.tf - Input Variables for Windows Infrastructure

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "fonteyn"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must only contain lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "test"
  
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "admin_username" {
  description = "Admin username for Windows VMs"
  type        = string
  default     = "azureadmin"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,19}$", var.admin_username)) && !contains(["administrator", "admin", "user", "root", "guest"], lower(var.admin_username))
    error_message = "Admin username must be 3-20 characters, start with letter, and not be a reserved name."
  }
}

variable "vm_size" {
  description = "Size of Windows VMs"
  type        = string
  default     = "Standard_B2s"  # 2 vCPU, 4GB RAM - good for Windows testing
  
  validation {
    condition = contains([
      "Standard_B1s",    # 1 vCPU, 1GB RAM - minimal (not recommended for Windows)
      "Standard_B2s",    # 2 vCPU, 4GB RAM - small Windows testing
      "Standard_B4ms",   # 4 vCPU, 16GB RAM - larger Windows testing
      "Standard_D2s_v3", # 2 vCPU, 8GB RAM - production-like
      "Standard_D4s_v3", # 4 vCPU, 16GB RAM - production Windows
      "Standard_D8s_v3"  # 8 vCPU, 32GB RAM - enterprise Windows
    ], var.vm_size)
    error_message = "VM size must be one of the allowed Windows-compatible sizes."
  }
}

variable "web_vm_count" {
  description = "Number of web server VMs"
  type        = number
  default     = 2
  
  validation {
    condition     = var.web_vm_count >= 1 && var.web_vm_count <= 5
    error_message = "Web VM count must be between 1 and 5."
  }
}

variable "app_vm_count" {
  description = "Number of app server VMs"
  type        = number
  default     = 1  # Reduced default for Windows testing
  
  validation {
    condition     = var.app_vm_count >= 1 && var.app_vm_count <= 3
    error_message = "App VM count must be between 1 and 3."
  }
}

variable "enable_monitoring" {
  description = "Enable basic monitoring and logging"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Auto shutdown time for VMs (24h format, e.g., '1900' for 7 PM)"
  type        = string
  default     = "1900"
  
  validation {
    condition     = can(regex("^[0-2][0-9][0-5][0-9]$", var.auto_shutdown_time))
    error_message = "Auto shutdown time must be in 24h format (e.g., '1900')."
  }
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access VMs via RDP. Use ['*'] for any IP (testing only!)"
  type        = list(string)
  default     = ["*"]  # WARNING: This allows RDP access from anywhere - only for testing!
  
  validation {
    condition     = length(var.allowed_ip_ranges) > 0
    error_message = "At least one IP range must be specified for RDP access."
  }
}

variable "enable_azure_hybrid_benefit" {
  description = "Enable Azure Hybrid Benefit for Windows Server (requires existing licenses with Software Assurance)"
  type        = bool
  default     = false
}

variable "windows_server_sku" {
  description = "Windows Server 2022 SKU to deploy"
  type        = string
  default     = "2022-datacenter-azure-edition"
  
  validation {
    condition = contains([
      "2022-datacenter",                # Standard Datacenter edition
      "2022-datacenter-azure-edition",  # Azure-optimized with additional features
      "2022-datacenter-core",           # Server Core (no GUI)
      "2022-datacenter-g2"              # Generation 2 with enhanced security
    ], var.windows_server_sku)
    error_message = "Windows Server SKU must be a valid Windows Server 2022 edition."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for Windows VMs"
  type        = number
  default     = 128  # Windows Server 2022 needs more space than Linux
  
  validation {
    condition     = var.os_disk_size_gb >= 128 && var.os_disk_size_gb <= 1024
    error_message = "OS disk size must be between 128GB and 1024GB for Windows Server."
  }
}

variable "storage_account_type" {
  description = "Storage account type for VM disks"
  type        = string
  default     = "Premium_LRS"  # Recommended for Windows performance
  
  validation {
    condition = contains([
      "Standard_LRS",  # Lower cost, good for testing
      "Premium_LRS",   # Better performance, recommended for Windows
      "StandardSSD_LRS" # Balanced option
    ], var.storage_account_type)
    error_message = "Storage account type must be Standard_LRS, Premium_LRS, or StandardSSD_LRS."
  }
}

variable "enable_backup" {
  description = "Enable Azure Backup for VMs"
  type        = bool
  default     = false  # Disabled for testing to reduce costs
}

variable "backup_retention_days" {
  description = "Number of days to retain VM backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

variable "enable_antimalware" {
  description = "Enable Microsoft Antimalware extension on VMs"
  type        = bool
  default     = true
}

variable "timezone" {
  description = "Timezone for Windows VMs"
  type        = string
  default     = "W. Europe Standard Time"
}

variable "domain_join" {
  description = "Configuration for joining VMs to Active Directory domain"
  type = object({
    enabled     = bool
    domain_name = string
    ou_path     = string
  })
  default = {
    enabled     = false
    domain_name = ""
    ou_path     = ""
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}