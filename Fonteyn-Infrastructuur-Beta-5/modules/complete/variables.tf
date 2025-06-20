# variables.tf - Input Variables

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
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "Size of VMs for testing"
  type        = string
  default     = "Standard_B2s"  # 2 vCPU, 4GB RAM - good for testing
  
  validation {
    condition = contains([
      "Standard_B1s",   # 1 vCPU, 1GB RAM - minimal
      "Standard_B2s",   # 2 vCPU, 4GB RAM - small testing
      "Standard_B4ms",  # 4 vCPU, 16GB RAM - larger testing
      "Standard_D2s_v3" # 2 vCPU, 8GB RAM - production-like
    ], var.vm_size)
    error_message = "VM size must be one of the allowed testing sizes."
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
  default     = 2
  
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
  description = "IP ranges allowed to access VMs (for security). Use ['*'] for any IP (testing only!)"
  type        = list(string)
  default     = ["*"]  # WARNING: This allows access from anywhere - only for testing!
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}