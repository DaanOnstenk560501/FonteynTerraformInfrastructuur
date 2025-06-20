# ==============================================================================
# STORAGE MODULE VARIABLES (COMPLETE & FIXED)
# ==============================================================================

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

variable "secondary_location" {
  description = "Secundaire Azure locatie (Noord-Europa)"
  type        = string
  default     = "North Europe"
}

# ==============================================================================
# SQL SERVER CONFIGURATION
# ==============================================================================

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

# ADDED: Missing Azure AD variables
variable "sql_azuread_admin_login" {
  description = "Azure AD admin login naam voor SQL Server"
  type        = string
}

variable "sql_azuread_admin_object_id" {
  description = "Azure AD admin object ID voor SQL Server"
  type        = string
}

# ==============================================================================
# NETWORK ACCESS CONFIGURATION
# ==============================================================================

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

# ==============================================================================
# BUDGET & COST MANAGEMENT
# ==============================================================================

variable "monthly_budget_limit" {
  description = "Maandelijks budget limiet in euros"
  type        = number
  default     = 5000
}

variable "budget_alert_emails" {
  description = "Email adressen voor budget alerts"
  type        = list(string)
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}