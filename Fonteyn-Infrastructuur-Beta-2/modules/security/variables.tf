variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}