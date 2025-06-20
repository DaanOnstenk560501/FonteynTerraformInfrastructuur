variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

variable "alert_email" {
  description = "Email adres voor alerts"
  type        = string
}

variable "vm_ids" {
  description = "List van VM IDs om te monitoren"
  type        = list(string)
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}