# Required Variables
variable "environment" {
  description = "Environment (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "fonteyn"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "North Europe"
}

variable "frontend_instance_count" {
  description = "Number of frontend instances"
  type        = number
  default     = 2
}

variable "backend_instance_count" {
  description = "Number of backend instances"
  type        = number
  default     = 2
}

variable "database_instance_count" {
  description = "Number of database instances"
  type        = number
  default     = 1
}

variable "frontend_vm_size" {
  description = "Frontend webserver VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "backend_vm_size" {
  description = "Backend application VM size"
  type        = string
  default     = "Standard_B4ms"
}

variable "database_vm_size" {
  description = "Database VM size"
  type        = string
  default     = "Standard_B8ms"
}

variable "monitoring_vm_size" {
  description = "Monitoring server VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "printserver_vm_size" {
  description = "Print server VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "sql_admin_username" {
  description = "SQL admin username"
  type        = string
  default     = "sqladmin"
}

variable "vpn_shared_key" {
  description = "Shared key for VPN connections"
  type        = string
  sensitive   = true
  default     = "FonteynEnterprise2024!"
}

variable "hoofdkantoor_gateway_ip" {
  description = "Hoofdkantoor VPN gateway IP"
  type        = string
  default     = "145.220.74.133"
}

variable "azure_vnet_address_space" {
  description = "Azure VNet CIDR - Enterprise addressing"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dmz_subnet_prefix" {
  description = "DMZ subnet for public-facing resources"
  type        = string
  default     = "10.0.1.0/24"
}

variable "frontend_subnet_prefix" {
  description = "Frontend webserver subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "backend_subnet_prefix" {
  description = "Backend application subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "database_subnet_prefix" {
  description = "Database subnet"
  type        = string
  default     = "10.0.4.0/24"
}

variable "management_subnet_prefix" {
  description = "Management and monitoring subnet"
  type        = string
  default     = "10.0.5.0/24"
}

variable "azure_arc_subnet_prefix" {
  description = "Azure Arc hybrid management subnet"
  type        = string
  default     = "10.0.6.0/24"
}

variable "onpremises_hoofdkantoor_cidr" {
  description = "Hoofdkantoor network"
  type        = string
  default     = "192.168.0.0/16"
}

variable "vakantiepark_nl_cidr" {
  description = "Vakantiepark Nederland"
  type        = string
  default     = "10.5.0.0/16"
}

variable "vakantiepark_be_cidr" {
  description = "Vakantiepark België"
  type        = string
  default     = "10.6.0.0/16"
}

variable "vakantiepark_de_cidr" {
  description = "Vakantiepark Duitsland"
  type        = string
  default     = "10.7.0.0/16"
}

variable "on_premises_networks" {
  description = "All on-premises networks"
  type        = list(string)
  default     = [
    "192.168.1.0/24",
    "192.168.2.0/24",
    "192.168.3.0/24",
    "10.5.0.0/16",
    "10.6.0.0/16",
    "10.7.0.0/16"
  ]
}

variable "on_premises_dns_servers" {
  description = "On-premises DNS servers"
  type        = list(string)
  default     = ["192.168.2.100"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project     = "fonteyn-enterprise"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "daan-onstenk"
    CostCenter  = "IT-Development"
    Purpose     = "vacation-parks-enterprise"
    Architecture = "hybrid-cloud"
  }
}
