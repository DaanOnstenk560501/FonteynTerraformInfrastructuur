# ========================================
# COMPUTE MODULE
# ========================================

# modules/compute/main.tf
# Resource Group voor compute resources
resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-compute"
  location = var.location
  tags     = merge(var.tags, {
    Purpose = "ComputeWorkloads"
  })
}

# ==============================================================================
# LOAD BALANCER & PUBLIC IP
# ==============================================================================

# Public IP voor Load Balancer (Standard SKU voor auto-scaling)
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "pip-${var.project_name}-lb"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"] # Zone redundancy
  
  tags = merge(var.tags, {
    Component = "LoadBalancer"
  })
}

# Load Balancer voor frontend servers (Standard voor auto-scaling)
resource "azurerm_lb" "frontend" {
  name                = "lb-${var.project_name}-frontend"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  tags = var.tags
}

# Backend pool voor load balancer
resource "azurerm_lb_backend_address_pool" "frontend" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "BackEndAddressPool"
}

# Health probe (HTTPS voor productie)
resource "azurerm_lb_probe" "frontend_https" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "https-probe"
  port            = 443
  protocol        = "Https"
  request_path    = "/health"
}

resource "azurerm_lb_probe" "frontend_http" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/health"
}

# Load balancer rules
resource "azurerm_lb_rule" "frontend_https" {
  loadbalancer_id                = azurerm_lb.frontend.id
  name                           = "HTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                       = azurerm_lb_probe.frontend_https.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

resource "azurerm_lb_rule" "frontend_http" {
  loadbalancer_id                = azurerm_lb.frontend.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                       = azurerm_lb_probe.frontend_http.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

# ==============================================================================
# AUTO-SCALING CONFIGURATION (VMSS voor front-end)
# ==============================================================================

# Virtual Machine Scale Set voor front-end webservers
resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = "vmss-${var.project_name}-frontend"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = var.frontend_vm_size
  instances           = var.frontend_min_instances
  
  # Auto-scaling configuratie
  upgrade_mode = "Automatic"
  
  # Managed identity voor Key Vault toegang
  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = var.frontend_subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend.id]
    }
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role      = "Frontend"
    Tier      = "Web"
    AutoScale = "Enabled"
  })
}

# Auto-scaling configuratie voor frontend VMSS
resource "azurerm_monitor_autoscale_setting" "frontend" {
  name                = "autoscale-${var.project_name}-frontend"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.frontend.id

  profile {
    name = "SeasonalProfile"

    capacity {
      default = var.frontend_min_instances
      minimum = var.frontend_min_instances
      maximum = var.frontend_max_instances
    }

    # Scale out regel (CPU > 70%)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.autoscale_cpu_threshold_out
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale in regel (CPU < 30%)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.autoscale_cpu_threshold_in
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }

  tags = var.tags
}

# ==============================================================================
# BACKEND APPLICATION SERVERS
# ==============================================================================

# Availability Set voor backend servers
resource "azurerm_availability_set" "backend" {
  name                         = "avset-${var.project_name}-backend"
  location                     = azurerm_resource_group.compute.location
  resource_group_name          = azurerm_resource_group.compute.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  
  tags = var.tags
}

# Network Interfaces voor backend servers
resource "azurerm_network_interface" "backend" {
  count               = var.backend_instance_count
  name                = "nic-${var.project_name}-backend-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.backend_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Backend Application Servers
resource "azurerm_linux_virtual_machine" "backend" {
  count               = var.backend_instance_count
  name                = "vm-${var.project_name}-backend-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.backend_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.backend.id

  # Managed identity voor Key Vault toegang
  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.backend[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role = "Backend"
    Tier = "Application"
  })
}

# Backup associatie voor backend VMs (alleen als backup enabled)
resource "azurerm_backup_protected_vm" "backend" {
  count               = var.enable_backup ? var.backend_instance_count : 0
  resource_group_name = var.backup_policy_id != "" ? split("/", var.backup_policy_id)[4] : ""
  recovery_vault_name = var.backup_policy_id != "" ? split("/", var.backup_policy_id)[8] : ""
  source_vm_id        = azurerm_linux_virtual_machine.backend[count.index].id
  backup_policy_id    = var.backup_policy_id
}

# ==============================================================================
# DATABASE SERVERS
# ==============================================================================

# Availability Set voor database servers
resource "azurerm_availability_set" "database" {
  name                         = "avset-${var.project_name}-database"
  location                     = azurerm_resource_group.compute.location
  resource_group_name          = azurerm_resource_group.compute.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  
  tags = var.tags
}

# Network Interfaces voor database servers
resource "azurerm_network_interface" "database" {
  count               = var.database_instance_count
  name                = "nic-${var.project_name}-database-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.database_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Database Servers
resource "azurerm_linux_virtual_machine" "database" {
  count               = var.database_instance_count
  name                = "vm-${var.project_name}-database-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.database_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.database.id

  # Managed identity voor Key Vault toegang
  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.database[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role = "Database"
    Tier = "Data"
  })
}

# Data disks voor database servers
resource "azurerm_managed_disk" "database_data" {
  count                = var.database_instance_count
  name                 = "disk-${var.project_name}-database-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.database_data_disk_size_gb

  tags = merge(var.tags, {
    Purpose = "DatabaseData"
  })
}

# Attach data disks to database VMs
resource "azurerm_virtual_machine_data_disk_attachment" "database" {
  count              = var.database_instance_count
  managed_disk_id    = azurerm_managed_disk.database_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  lun                = 0
  caching            = "ReadOnly"
}

# Backup associatie voor database VMs (alleen als backup enabled)
resource "azurerm_backup_protected_vm" "database" {
  count               = var.enable_backup ? var.database_instance_count : 0
  resource_group_name = var.backup_policy_id != "" ? split("/", var.backup_policy_id)[4] : ""
  recovery_vault_name = var.backup_policy_id != "" ? split("/", var.backup_policy_id)[8] : ""
  source_vm_id        = azurerm_linux_virtual_machine.database[count.index].id
  backup_policy_id    = var.backup_policy_id
}

# ==============================================================================
# INTERNAL LOAD BALANCER (Backend naar Database)
# ==============================================================================

# Internal Load Balancer voor database servers
resource "azurerm_lb" "database_internal" {
  name                = "lb-${var.project_name}-database-internal"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "DatabaseFrontend"
    subnet_id                     = var.database_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Backend pool voor database load balancer
resource "azurerm_lb_backend_address_pool" "database" {
  loadbalancer_id = azurerm_lb.database_internal.id
  name            = "DatabaseBackendPool"
}

# Health probe voor database
resource "azurerm_lb_probe" "database" {
  loadbalancer_id = azurerm_lb.database_internal.id
  name            = "database-probe"
  port            = 3306
  protocol        = "Tcp"
}

# Load balancer rule voor database
resource "azurerm_lb_rule" "database" {
  loadbalancer_id                = azurerm_lb.database_internal.id
  name                           = "DatabaseRule"
  protocol                       = "Tcp"
  frontend_port                  = 3306
  backend_port                   = 3306
  frontend_ip_configuration_name = "DatabaseFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.database.id]
  probe_id                       = azurerm_lb_probe.database.id
}

# Database servers toevoegen aan load balancer backend pool
resource "azurerm_network_interface_backend_address_pool_association" "database" {
  count                   = var.database_instance_count
  network_interface_id    = azurerm_network_interface.database[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.database.id
}

# ==============================================================================
# AUTO-SHUTDOWN VOOR DEV/TEST
# ==============================================================================

# Auto-shutdown voor backend VMs in dev/test
resource "azurerm_dev_test_global_vm_shutdown_schedule" "backend" {
  count = var.environment != "prod" ? var.backend_instance_count : 0
  
  virtual_machine_id = azurerm_linux_virtual_machine.backend[count.index].id
  location           = azurerm_resource_group.compute.location
  enabled            = true

  daily_recurrence_time = "1900"
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }
}

# Auto-shutdown voor database VMs in dev/test
resource "azurerm_dev_test_global_vm_shutdown_schedule" "database" {
  count = var.environment != "prod" ? var.database_instance_count : 0
  
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  location           = azurerm_resource_group.compute.location
  enabled            = true

  daily_recurrence_time = "1900"
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }
}

# modules/compute/outputs.tf
output "compute_resource_group_name" {
  value = azurerm_resource_group.compute.name
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_public_ip.ip_address
}

# Frontend VMSS outputs
output "frontend_vmss_id" {
  value = azurerm_linux_virtual_machine_scale_set.frontend.id
}

output "frontend_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.frontend.name
}

# Backend VM outputs
output "backend_vm_ids" {
  value = azurerm_linux_virtual_machine.backend[*].id
}

output "backend_vm_private_ips" {
  value = azurerm_network_interface.backend[*].ip_configuration[0].private_ip_address
}

# Database VM outputs
output "database_vm_ids" {
  value = azurerm_linux_virtual_machine.database[*].id
}

output "database_vm_private_ips" {
  value = azurerm_network_interface.database[*].ip_configuration[0].private_ip_address
}

# Load Balancer outputs
output "frontend_lb_id" {
  value = azurerm_lb.frontend.id
}

output "database_internal_lb_ip" {
  value = azurerm_lb.database_internal.frontend_ip_configuration[0].private_ip_address
}

# Availability Set outputs
output "backend_availability_set_id" {
  value = azurerm_availability_set.backend.id
}

output "database_availability_set_id" {
  value = azurerm_availability_set.database.id
}

# modules/compute/variables.tf
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

# Network Configuration
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

# VM Sizes
variable "frontend_vm_size" {
  description = "VM grootte voor frontend webservers"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "backend_vm_size" {
  description = "VM grootte voor backend applicatieservers"
  type        = string
  default     = "Standard_D16s_v5"
}

variable "database_vm_size" {
  description = "VM grootte voor database servers"
  type        = string
  default     = "Standard_E16ds_v5"
}

# Auto-scaling Configuration
variable "frontend_min_instances" {
  description = "Minimum aantal frontend instances"
  type        = number
  default     = 2
}

variable "frontend_max_instances" {
  description = "Maximum aantal frontend instances"
  type        = number
  default     = 8
}

variable "autoscale_cpu_threshold_out" {
  description = "CPU percentage voor scale-out"
  type        = number
  default     = 70
}

variable "autoscale_cpu_threshold_in" {
  description = "CPU percentage voor scale-in"
  type        = number
  default     = 30
}

# Storage & Disk Configuration
variable "database_data_disk_size_gb" {
  description = "Database data disk grootte in GB"
  type        = number
  default     = 1024
}

variable "storage_account_uri" {
  description = "Storage account URI voor boot diagnostics"
  type        = string
}

# Security & Access
variable "admin_username" {
  description = "Admin gebruikersnaam voor VMs"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key voor VM toegang"
  type        = string
}

variable "managed_identity_id" {
  description = "User assigned managed identity ID voor Key Vault toegang"
  type        = string
}

# Instance Counts
variable "backend_instance_count" {
  description = "Aantal backend servers"
  type        = number
  default     = 4
}

variable "database_instance_count" {
  description = "Aantal database servers"
  type        = number
  default     = 2
}

# Backup & Monitoring
variable "enable_backup" {
  description = "VM backups inschakelen"
  type        = bool
  default     = true
}

variable "backup_policy_id" {
  description = "Backup policy ID (uit security module)"
  type        = string
  default     = ""
}

# Tagging
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}