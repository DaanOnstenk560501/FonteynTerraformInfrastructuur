# Dit zijn de "instellingen" die je kunt aanpassen voor de networking module

variable "project_name" {
  description = "Naam van het project (bijv. fonteyn)"
  type        = string
}

variable "location" {
  description = "Azure regio waar alles komt"
  type        = string
  default     = "West Europe"
}

variable "vnet_address_space" {
  description = "IP range voor het hele netwerk"
  type        = string
  default     = "10.0.0.0/16"
}

variable "frontend_subnet_prefix" {
  description = "IP range voor webservers"
  type        = string
  default     = "10.0.1.0/24"
}

variable "backend_subnet_prefix" {
  description = "IP range voor app servers"
  type        = string
  default     = "10.0.2.0/24"
}

variable "database_subnet_prefix" {
  description = "IP range voor database"
  type        = string
  default     = "10.0.3.0/24"
}

variable "tags" {
  description = "Labels voor alle resources"
  type        = map(string)
  default = {
    Project   = "fonteyn-iac"
    ManagedBy = "terraform"
  }
}