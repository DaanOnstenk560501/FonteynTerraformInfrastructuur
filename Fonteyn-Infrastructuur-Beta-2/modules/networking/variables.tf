variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
  default     = "West Europe"
}

variable "vnet_address_space" {
  description = "VNet CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "frontend_subnet_prefix" {
  description = "Frontend subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "backend_subnet_prefix" {
  description = "Backend subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "database_subnet_prefix" {
  description = "Database subnet CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

variable "management_subnet_prefix" {
  description = "Management subnet CIDR"
  type        = string
  default     = "10.0.4.0/24"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}