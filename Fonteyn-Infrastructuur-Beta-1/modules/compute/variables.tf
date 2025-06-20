variable "project_name" {
  description = "Project naam"
  type        = string
}

variable "location" {
  description = "Azure locatie"
  type        = string
}

variable "frontend_subnet_id" {
  description = "Frontend subnet ID"
  type        = string
}

variable "backend_subnet_id" {
  description = "Backend subnet ID"
  type        = string
}

variable "database_subnet_id" {
  description = "Database subnet ID"
  type        = string
}

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

variable "admin_username" {
  description = "Admin gebruikersnaam voor VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key voor VM toegang"
  type        = string
}

variable "storage_account_uri" {
  description = "Storage account URI voor boot diagnostics"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}