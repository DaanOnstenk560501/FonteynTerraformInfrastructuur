variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

variable "frontend_subnet_id" {
  description = "Frontend subnet ID"
  type        = string
}

variable "backend_subnet_id" {
  description = "Backend subnet ID"
  type        = string
}

variable "database_subnet_id" {
  description = "Database subnet ID"
  type        = string
}

# ==============================================================================
# VM SIZES (conform technisch ontwerp)
# ==============================================================================

variable "frontend_vm_size" {
  description = "VM grootte voor frontend webservers (technisch ontwerp: D8s v5)"
  type        = string
  default     = "Standard_D8s_v5" # 8 vCPU, 32 GB RAM
  validation {
    condition = contains([
      "Standard_D8s_v5", "Standard_D4s_v5", "Standard_D2s_v5" # Dev opties
    ], var.frontend_vm_size)
    error_message = "Frontend VM size moet D8s_v5 zijn voor productie (D2s/D4s voor dev)."
  }
}

variable "backend_vm_size" {
  description = "VM grootte voor backend applicatieservers (technisch ontwerp: D16s v5)"
  type        = string
  default     = "Standard_D16s_v5" # 16 vCPU, 64 GB RAM
  validation {
    condition = contains([
      "Standard_D16s_v5", "Standard_D8s_v5", "Standard_D4s_v5" # Dev opties
    ], var.backend_vm_size)
    error_message = "Backend VM size moet D16s_v5 zijn voor productie (D4s/D8s voor dev)."
  }
}

variable "database_vm_size" {
  description = "VM grootte voor database servers (technisch ontwerp: E16ds v5)"
  type        = string
  default     = "Standard_E16ds_v5" # 16 vCPU, 128 GB RAM, Premium SSD
  validation {
    condition = contains([
      "Standard_E16ds_v5", "Standard_E8ds_v5", "Standard_E4ds_v5" # Dev opties
    ], var.database_vm_size)
    error_message = "Database VM size moet E16ds_v5 zijn voor productie (E4ds/E8ds voor dev)."
  }
}

# ==============================================================================
# AUTO-SCALING CONFIGURATION
# ==============================================================================

variable "frontend_min_instances" {
  description = "Minimum aantal frontend instances"
  type        = number
  default     = 2
}

variable "frontend_max_instances" {
  description = "Maximum aantal frontend instances (technisch ontwerp: tot 8)"
  type        = number
  default     = 8
  validation {
    condition     = var.frontend_max_instances <= 8
    error_message = "Maximum frontend instances mag niet meer dan 8 zijn conform technisch ontwerp."
  }
}

variable "autoscale_cpu_threshold_out" {
  description = "CPU percentage voor scale-out"
  type        = number
  default     = 70
}

variable "autoscale_cpu_threshold_in" {
  description = "CPU percentage voor scale-in"
  type        = number
  default     = 30
}

# ==============================================================================
# STORAGE & DISK CONFIGURATION
# ==============================================================================

variable "database_data_disk_size_gb" {
  description = "Database data disk grootte in GB"
  type        = number
  default     = 1024 # 1TB voor productie
}

variable "storage_account_uri" {
  description = "Storage account URI voor boot diagnostics"
  type        = string
}

# ==============================================================================
# SECURITY & ACCESS
# ==============================================================================

variable "admin_username" {
  description = "Admin gebruikersnaam voor VMs"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key voor VM toegang"
  type        = string
}

variable "managed_identity_id" {
  description = "User assigned managed identity ID voor Key Vault toegang"
  type        = string
}

# ==============================================================================
# ENVIRONMENT & INSTANCE COUNTS
# ==============================================================================

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment moet dev, staging, of prod zijn."
  }
}

variable "backend_instance_count" {
  description = "Aantal backend servers (technisch ontwerp: 4)"
  type        = number
  default     = 4
  validation {
    condition     = var.backend_instance_count >= 2 && var.backend_instance_count <= 8
    error_message = "Backend instance count moet tussen 2 en 8 zijn."
  }
}

variable "database_instance_count" {
  description = "Aantal database servers (technisch ontwerp: 2)"
  type        = number
  default     = 2
  validation {
    condition     = var.database_instance_count >= 1 && var.database_instance_count <= 3
    error_message = "Database instance count moet tussen 1 en 3 zijn."
  }
}

# ==============================================================================
# LOAD BALANCER CONFIGURATION
# ==============================================================================

variable "enable_https_probe" {
  description = "HTTPS health probe inschakelen (productie)"
  type        = bool
  default     = true
}

variable "load_balancer_idle_timeout" {
  description = "Load balancer idle timeout in minuten"
  type        = number
  default     = 15
}

# ==============================================================================
# BACKUP & MONITORING
# ==============================================================================

variable "enable_backup" {
  description = "VM backups inschakelen"
  type        = bool
  default     = true
}

variable "backup_policy_id" {
  description = "Backup policy ID (uit security module)"
  type        = string
  default     = ""
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}