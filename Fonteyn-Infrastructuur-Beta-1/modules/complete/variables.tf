# Variabelen voor de complete Fonteyn infrastructuur

variable "project_name" {
  description = "Naam van het project"
  type        = string
  default     = "fonteyn"
}

variable "location" {
  description = "Azure regio"
  type        = string
  default     = "West Europe"
}

variable "environment" {
  description = "Omgeving naam"
  type        = string
  default     = "complete"
}

# Netwerk variabelen
variable "vnet_address_space" {
  description = "VNet address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "frontend_subnet_prefix" {
  description = "Frontend subnet prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "backend_subnet_prefix" {
  description = "Backend subnet prefix"
  type        = string
  default     = "10.0.2.0/24"
}

variable "database_subnet_prefix" {
  description = "Database subnet prefix"
  type        = string
  default     = "10.0.3.0/24"
}

variable "management_subnet_prefix" {
  description = "Management subnet prefix"
  type        = string
  default     = "10.0.4.0/24"
}

# VM configuratie
variable "vm_size_web" {
  description = "VM grootte voor web servers"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_size_app" {
  description = "VM grootte voor app servers"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_size_db" {
  description = "VM grootte voor database server"
  type        = string
  default     = "Standard_D4s_v5"
}

# Alert configuratie
variable "alert_email" {
  description = "Email adres voor alerts"
  type        = string
  default     = "admin@example.com"
}

# Tags
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}