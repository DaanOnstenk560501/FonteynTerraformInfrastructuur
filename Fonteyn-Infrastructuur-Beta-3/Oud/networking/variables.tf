# ==============================================================================
# NETWORKING MODULE VARIABLES (FIXED & SIMPLIFIED)
# ==============================================================================

variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment moet dev, staging, of prod zijn."
  }
}

# ==============================================================================
# HUB NETWORK CONFIGURATION
# ==============================================================================

variable "hub_vnet_address_space" {
  description = "Hub VNet CIDR (Azure central hub)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "gateway_subnet_prefix" {
  description = "Gateway subnet CIDR (voor VPN Gateway)"
  type        = string
  default     = "10.0.0.0/27"
}

variable "firewall_subnet_prefix" {
  description = "Azure Firewall subnet CIDR"
  type        = string
  default     = "10.0.1.0/26"
}

variable "bastion_subnet_prefix" {
  description = "Azure Bastion subnet CIDR"
  type        = string
  default     = "10.0.2.0/27"
}

variable "hub_management_subnet_prefix" {
  description = "Hub management subnet CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

# ==============================================================================
# WORKLOAD SPOKE CONFIGURATION
# ==============================================================================

variable "workload_vnet_address_space" {
  description = "Workload spoke VNet CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "frontend_subnet_prefix" {
  description = "Frontend subnet CIDR"
  type        = string
  default     = "10.1.1.0/24"
}

variable "backend_subnet_prefix" {
  description = "Backend subnet CIDR"
  type        = string
  default     = "10.1.2.0/24"
}

variable "database_subnet_prefix" {
  description = "Database subnet CIDR"
  type        = string
  default     = "10.1.3.0/24"
}

# ==============================================================================
# PARK SPOKE NETWORKS (SIMPLIFIED - Remove unused variables)
# ==============================================================================

variable "netherlands_parks_address_space" {
  description = "Nederlandse parken VNet CIDR"
  type        = string
  default     = "10.101.0.0/16"
}

variable "belgium_parks_address_space" {
  description = "Belgische parken VNet CIDR"
  type        = string
  default     = "10.110.0.0/16"
}

variable "germany_parks_address_space" {
  description = "Duitse parken VNet CIDR"
  type        = string
  default     = "10.120.0.0/16"
}

# ==============================================================================
# SECURITY & NETWORK FEATURES
# ==============================================================================

variable "enable_azure_firewall" {
  description = "Azure Firewall inschakelen"
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Azure Bastion inschakelen"
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU"
  type        = string
  default     = "VpnGw1"
  validation {
    condition = contains(["VpnGw1", "VpnGw2", "VpnGw3"], var.vpn_gateway_sku)
    error_message = "VPN Gateway SKU moet VpnGw1, VpnGw2, of VpnGw3 zijn."
  }
}

variable "enable_bgp" {
  description = "BGP inschakelen voor VPN Gateway"
  type        = bool
  default     = true
}

variable "allowed_management_ips" {
  description = "IP ranges voor management toegang"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}