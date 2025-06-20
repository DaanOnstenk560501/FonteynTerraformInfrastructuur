variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "sql_admin_password" {
  description = "SQL Server admin wachtwoord"
  type        = string
  sensitive   = true
}

variable "storage_account_key" {
  description = "Storage account access key"
  type        = string
  sensitive   = true
}

# Nieuwe beveiligingsvariabelen
variable "admin_group_id" {
  description = "Azure AD groep ID voor beheerders (voor Conditional Access)"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "IP ranges die toegang hebben tot Key Vault"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs die toegang hebben tot Key Vault"
  type        = list(string)
  default     = []
}

variable "admin_ip_ranges" {
  description = "IP ranges voor beheerders SSH/RDP toegang"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Alleen interne ranges
}

variable "security_alert_email" {
  description = "Email adres voor security alerts"
  type        = string
}

variable "security_alert_phone" {
  description = "Telefoonnummer voor kritieke security alerts"
  type        = string
  default     = ""
}

variable "enable_defender" {
  description = "Azure Defender inschakelen (Standard tier)"
  type        = bool
  default     = true
}

variable "enable_ddos_protection" {
  description = "DDoS Protection Plan inschakelen"
  type        = bool
  default     = false # Alleen voor productie
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention (dagen)"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "sql_azuread_admin_login" {
  description = "Azure AD admin login naam voor SQL Server"
  type        = string
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID voor SQL Server"
  type        = string
}