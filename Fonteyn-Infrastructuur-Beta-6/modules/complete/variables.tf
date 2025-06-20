# variables.tf - Complete Variable Definitions for Fonteyn Hybrid Infrastructure

# Project Configuration
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
  default     = "hybrid"
  
  validation {
    condition     = contains(["dev", "test", "prod", "hybrid"], var.environment)
    error_message = "Environment must be dev, test, prod, or hybrid."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
  
  validation {
    condition = contains([
      "West Europe", "North Europe", "East US", "East US 2", "West US", "West US 2", 
      "Central US", "South Central US", "North Central US", "West Central US",
      "Canada Central", "Canada East", "UK South", "UK West"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

# VM Configuration
variable "admin_username" {
  description = "Admin username for Windows VMs (will be used for domain join)"
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
  default     = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM - good for Windows production
  
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
  default     = 2
  
  validation {
    condition     = var.app_vm_count >= 1 && var.app_vm_count <= 3
    error_message = "App VM count must be between 1 and 3."
  }
}

# Windows Configuration
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
  default     = 128
  
  validation {
    condition     = var.os_disk_size_gb >= 128 && var.os_disk_size_gb <= 1024
    error_message = "OS disk size must be between 128GB and 1024GB for Windows Server."
  }
}

variable "storage_account_type" {
  description = "Storage account type for VM disks"
  type        = string
  default     = "Premium_LRS"
  
  validation {
    condition = contains([
      "Standard_LRS",   # Lower cost, good for testing
      "Premium_LRS",    # Better performance, recommended for Windows
      "StandardSSD_LRS" # Balanced option
    ], var.storage_account_type)
    error_message = "Storage account type must be Standard_LRS, Premium_LRS, or StandardSSD_LRS."
  }
}

variable "timezone" {
  description = "Timezone for Windows VMs"
  type        = string
  default     = "W. Europe Standard Time"
}

variable "enable_azure_hybrid_benefit" {
  description = "Enable Azure Hybrid Benefit for Windows Server (requires existing licenses with Software Assurance)"
  type        = bool
  default     = false
}

# Security Configuration
variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access VMs via RDP (include your office/home IP)"
  type        = list(string)
  default     = [
    "145.220.74.133/32",  # Fonteyn office public IP
    "192.168.1.0/24",     # Fonteyn VLAN A
    "192.168.2.0/24",     # Fonteyn VLAN B (DCs)
    "192.168.3.0/24"      # Fonteyn VLAN C
  ]
  
  validation {
    condition     = length(var.allowed_ip_ranges) > 0
    error_message = "At least one IP range must be specified for RDP access."
  }
}

variable "enable_antimalware" {
  description = "Enable Microsoft Antimalware extension on VMs"
  type        = bool
  default     = true
}

# Monitoring and Management
variable "enable_monitoring" {
  description = "Enable basic monitoring and logging"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Auto shutdown time for VMs (24h format, e.g., '1900' for 7 PM). Set to empty string to disable."
  type        = string
  default     = "1900"
  
  validation {
    condition     = var.auto_shutdown_time == "" || can(regex("^[0-2][0-9][0-5][0-9]$", var.auto_shutdown_time))
    error_message = "Auto shutdown time must be in 24h format (e.g., '1900') or empty string."
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

# Active Directory and Domain Configuration
variable "domain_join" {
  description = "Configuration for joining VMs to Fonteyn Active Directory domain"
  type = object({
    enabled     = bool
    domain_name = string
    ou_path     = string
  })
  default = {
    enabled     = true
    domain_name = "fonteyn.corp"
    ou_path     = "OU=Azure-VMs,DC=fonteyn,DC=corp"
  }
}

variable "active_directory_domain" {
  description = "Fonteyn Active Directory domain name"
  type        = string
  default     = "fonteyn.corp"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+$", var.active_directory_domain))
    error_message = "Domain name must be a valid FQDN."
  }
}

variable "active_directory_netbios" {
  description = "Fonteyn Active Directory NetBIOS name"
  type        = string
  default     = "FONTEYN"
  
  validation {
    condition     = can(regex("^[A-Z0-9]{1,15}$", var.active_directory_netbios))
    error_message = "NetBIOS name must be 1-15 uppercase characters."
  }
}

# Hybrid Connectivity Configuration
variable "enable_hybrid_connectivity" {
  description = "Enable hybrid connectivity to Fonteyn on-premise infrastructure"
  type        = bool
  default     = true
}

variable "hybrid_connectivity_type" {
  description = "Type of hybrid connectivity (vpn or expressroute)"
  type        = string
  default     = "vpn"
  
  validation {
    condition     = contains(["vpn", "expressroute"], var.hybrid_connectivity_type)
    error_message = "Hybrid connectivity type must be either 'vpn' or 'expressroute'."
  }
}

# VPN Gateway Configuration for Fonteyn
variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1"
  
  validation {
    condition = contains([
      "Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5"
    ], var.vpn_gateway_sku)
    error_message = "VPN Gateway SKU must be a valid option."
  }
}

variable "onpremise_gateway_ip" {
  description = "Public IP address of Fonteyn on-premise VPN gateway"
  type        = string
  default     = "145.220.74.133"
  
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.onpremise_gateway_ip))
    error_message = "On-premise gateway IP must be a valid IPv4 address."
  }
}

variable "onpremise_address_spaces" {
  description = "Address spaces of Fonteyn on-premise network"
  type        = list(string)
  default     = [
    "192.168.1.0/24",  # Fonteyn VLAN A
    "192.168.2.0/24",  # Fonteyn VLAN B (Domain Controllers)
    "192.168.3.0/24"   # Fonteyn VLAN C
  ]
  
  validation {
    condition     = length(var.onpremise_address_spaces) > 0
    error_message = "At least one on-premise address space must be specified."
  }
}

variable "vpn_shared_key" {
  description = "Shared key for VPN connection between Azure and Fonteyn"
  type        = string
  default     = "FonteynAzureVPN2024!SecureKey"
  sensitive   = true
  
  validation {
    condition     = length(var.vpn_shared_key) >= 8
    error_message = "VPN shared key must be at least 8 characters long."
  }
}

variable "onpremise_bgp_asn" {
  description = "BGP ASN for Fonteyn on-premise network"
  type        = number
  default     = 65001
  
  validation {
    condition     = var.onpremise_bgp_asn >= 64512 && var.onpremise_bgp_asn <= 65534
    error_message = "BGP ASN must be in the private range (64512-65534)."
  }
}

variable "onpremise_bgp_peer_ip" {
  description = "BGP peer IP for Fonteyn on-premise network (DC1 IP)"
  type        = string
  default     = "192.168.2.100"
  
  validation {
    condition     = can(regex("^192\\.168\\.2\\.[0-9]{1,3}$", var.onpremise_bgp_peer_ip))
    error_message = "BGP peer IP must be in the DC VLAN (192.168.2.x)."
  }
}

variable "onpremise_dns_servers" {
  description = "DNS servers in Fonteyn on-premise environment"
  type        = list(string)
  default     = ["192.168.2.100"]  # Only DC1 for simplicity
  
  validation {
    condition     = length(var.onpremise_dns_servers) > 0
    error_message = "At least one DNS server must be specified."
  }
}

# ExpressRoute Configuration (future use)
variable "expressroute_gateway_sku" {
  description = "SKU for ExpressRoute Gateway (if ExpressRoute is chosen later)"
  type        = string
  default     = "Standard"
  
  validation {
    condition = contains([
      "Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ"
    ], var.expressroute_gateway_sku)
    error_message = "ExpressRoute Gateway SKU must be a valid option."
  }
}

variable "expressroute_circuit_id" {
  description = "Resource ID of the ExpressRoute circuit (future use)"
  type        = string
  default     = ""
}

# Administrative Configuration
variable "admin_email" {
  description = "Administrator email for notifications"
  type        = string
  default     = "admin@fonteyn.corp"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.admin_email))
    error_message = "Admin email must be a valid email address."
  }
}

# Additional tags for resources
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
