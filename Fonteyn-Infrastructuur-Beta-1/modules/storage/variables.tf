variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

variable "sql_admin_username" {
  description = "SQL Server admin gebruikersnaam"
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server admin wachtwoord"
  type        = string
  sensitive   = true
}

variable "vnet_address_start" {
  description = "Start IP van VNet range"
  type        = string
  default     = "10.0.0.0"
}

variable "vnet_address_end" {
  description = "Eind IP van VNet range"
  type        = string
  default     = "10.0.255.255"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}