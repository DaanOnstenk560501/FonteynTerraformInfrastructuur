variable "project_name" {
  description = "A short name for the project, used in naming conventions."
  type        = string
  default     = "fonteyn" # Example default
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'test', 'production')."
  type        = string
  default     = "dev" # Example default
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "West Europe" # Adjust to your preferred region
}

variable "virtual_network_address_space" {
  description = "The address space for the virtual network (e.g., ['10.0.0.0/16'])."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_configs" {
  description = "A map of subnet configurations."
  type = map(object({
    address_prefixes = list(string)
  }))
  default = {
    "gateway" = {
      address_prefixes = ["10.0.0.0/27"] # Required for VPN Gateway
    }
    "servers" = {
      address_prefixes = ["10.0.1.0/24"]
    }
    "workstations" = {
      address_prefixes = ["10.0.2.0/24"]
    }
  }
}

variable "admin_username" {
  description = "The username for the administrator account on the VMs."
  type        = string
  default     = "fonteynAdmin"
}

variable "server_private_ips" {
  description = "A map of server names to their desired private IP addresses."
  type        = map(string)
  default = {
    "appserver"   = "10.0.1.60" # This VM will now be created.
    "workstation" = "10.0.2.10" # This is a new VM to be created.
    "database"    = "10.0.1.61" # This is a new VM to be created.
    "fileserver"  = "10.0.1.62" # This is a new VM to be created.
    # "webserver"   = "10.0.1.50" # Removed to adhere to 4 VM limit
    # "printserver" = "10.0.1.40" # Removed to adhere to 4 VM limit
  }
}

variable "enable_vm_shutdown_schedule" {
  description = "Whether to enable automatic shutdown for VMs."
  type        = bool
  default     = true
}

variable "vm_shutdown_time" {
  description = "The time in UTC (HHMM format) for VM shutdown."
  type        = string
  default     = "1900" # 7 PM UTC
}

variable "vm_shutdown_timezone" {
  description = "The timezone for VM shutdown (e.g., 'W. Europe Standard Time')."
  type        = string
  default     = "W. Europe Standard Time"
}

variable "windows_server_image_publisher" {
  description = "Publisher of the Windows Server image."
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "windows_server_image_offer" {
  description = "Offer of the Windows Server image."
  type        = string
  default     = "WindowsServer"
}

variable "windows_server_image_sku" {
  description = "SKU of the Windows Server image."
  type        = string
  default     = "2019-Datacenter" # Or "2022-Datacenter"
}

variable "windows_server_image_version" {
  description = "Version of the Windows Server image."
  type        = string
  default     = "latest"
}