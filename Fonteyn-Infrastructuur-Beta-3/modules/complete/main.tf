# Complete Fonteyn Infrastructure - SINGLE FILE SOLUTION (SYNTAX FIXED)
# Alle infrastructuur in één bestand voor eenvoudige deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = var.environment != "prod"
      purge_soft_deleted_keys_on_destroy = var.environment != "prod"
    }
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }
  }
}

# Data sources
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# ==============================================================================
# VARIABLES
# ==============================================================================

variable "project_name" {
  description = "Project naam"
  type        = string
  default     = "fonteyn-iac"
}

variable "location" {
  description = "Azure locatie"
  type        = string
  default     = "North Europe"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "hub_vnet_address_space" {
  description = "Hub VNet CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "workload_vnet_address_space" {
  description = "Workload VNet CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "frontend_subnet_prefix" {
  description = "Frontend subnet CIDR"
  type        = string
  default     = "10.1.1.0/24"
}

variable "backend_subnet_prefix" {
  description = "Backend subnet CIDR"
  type        = string
  default     = "10.1.2.0/24"
}

variable "database_subnet_prefix" {
  description = "Database subnet CIDR"
  type        = string
  default     = "10.1.3.0/24"
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureadmin"
}

variable "sql_admin_username" {
  description = "SQL admin username"
  type        = string
  default     = "sqladmin"
}

variable "frontend_vm_size" {
  description = "Frontend VM size"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "backend_vm_size" {
  description = "Backend VM size"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "database_vm_size" {
  description = "Database VM size"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "backend_instance_count" {
  description = "Backend instance count"
  type        = number
  default     = 2
}

variable "database_instance_count" {
  description = "Database instance count"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project     = "fonteyn-iac"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "daan-onstenk"
    CostCenter  = "IT-Development"
  }
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    DeployDate  = timestamp()
  })
}

# ==============================================================================
# RANDOM RESOURCES
# ==============================================================================

resource "random_password" "sql_admin" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ==============================================================================
# NETWORKING RESOURCES
# ==============================================================================

resource "azurerm_resource_group" "network" {
  name     = "rg-${var.project_name}-network"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}"
  address_space       = [var.workload_vnet_address_space]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.frontend_subnet_prefix]
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.backend_subnet_prefix]
}

resource "azurerm_subnet" "database" {
  name                 = "snet-database"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.database_subnet_prefix]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.4.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromFrontend"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.frontend_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "database" {
  name                = "nsg-database"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromBackend"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = var.backend_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.1.4.0/24"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Subnet NSG Associations
resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# ==============================================================================
# SECURITY RESOURCES
# ==============================================================================

resource "azurerm_resource_group" "security" {
  name     = "rg-${var.project_name}-security"
  location = var.location
  tags     = local.common_tags
}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project_name}-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Set", "Get", "List", "Delete"
  ]

  key_permissions = [
    "Create", "Get", "List", "Update", "Delete"
  ]

  certificate_permissions = [
    "Create", "Get", "List", "Update", "Delete"
  ]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
  tags       = local.common_tags
}

# ==============================================================================
# STORAGE RESOURCES
# ==============================================================================

resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.project_name}-storage"
  location = var.location
  tags     = local.common_tags
}

resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                     = "st${replace(var.project_name, "-", "")}files${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

resource "azurerm_storage_account" "diagnostics" {
  name                     = "st${replace(var.project_name, "-", "")}diag${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags
}

resource "azurerm_storage_share" "main" {
  name                 = "${var.project_name}-shared-files"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100
}

resource "azurerm_storage_table" "main" {
  name                 = "fonteydata"
  storage_account_name = azurerm_storage_account.main.name
}

# ==============================================================================
# MONITORING RESOURCES
# ==============================================================================

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${var.project_name}-monitoring"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.project_name}"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "fonteyn"

  email_receiver {
    name          = "admin"
    email_address = "560501@student.fontys.nl"
  }

  tags = local.common_tags
}

# ==============================================================================
# COMPUTE RESOURCES
# ==============================================================================

resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-compute"
  location = var.location
  tags     = local.common_tags
}

# Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "pip-${var.project_name}-lb"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_lb" "frontend" {
  name                = "lb-${var.project_name}-frontend"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "frontend" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "frontend" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "frontend" {
  loadbalancer_id                = azurerm_lb.frontend.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                      = azurerm_lb_probe.frontend.id
}

# Availability Sets
resource "azurerm_availability_set" "web" {
  name                = "avset-web"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true

  tags = local.common_tags
}

resource "azurerm_availability_set" "app" {
  name                = "avset-app"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true

  tags = local.common_tags
}

# Network Interfaces - FIXED: Removed :02d formatting
resource "azurerm_network_interface" "web" {
  count               = 2
  name                = "nic-web-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_network_interface" "app" {
  count               = var.backend_instance_count
  name                = "nic-app-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_network_interface" "db" {
  count               = var.database_instance_count
  name                = "nic-db-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

# Network Interface Load Balancer Associations
resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.frontend.id
}

# Virtual Machines - FIXED: Removed :02d formatting
resource "azurerm_linux_virtual_machine" "web" {
  count               = 2
  name                = "vm-web-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.frontend_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.web.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "webserver"
  })
}

resource "azurerm_linux_virtual_machine" "app" {
  count               = var.backend_instance_count
  name                = "vm-app-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.backend_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.app.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "appserver"
  })
}

resource "azurerm_linux_virtual_machine" "db" {
  count               = var.database_instance_count
  name                = "vm-db-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.database_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.db[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "database"
  })
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    project_name = var.project_name
    environment  = var.environment
    location     = var.location
    
    resource_groups = {
      network    = azurerm_resource_group.network.name
      compute    = azurerm_resource_group.compute.name
      storage    = azurerm_resource_group.storage.name
      security   = azurerm_resource_group.security.name
      monitoring = azurerm_resource_group.monitoring.name
    }
    
    web_servers = {
      private_ips = azurerm_network_interface.web[*].ip_configuration[0].private_ip_address
    }
    
    app_servers = {
      private_ips = azurerm_network_interface.app[*].ip_configuration[0].private_ip_address
    }
    
    database_server = {
      private_ip = var.database_instance_count > 0 ? azurerm_network_interface.db[0].ip_configuration[0].private_ip_address : null
    }
    
    load_balancer_ip = azurerm_public_ip.lb_public_ip.ip_address
    vnet_name = azurerm_virtual_network.main.name
    key_vault_name = azurerm_key_vault.main.name
    storage_table = azurerm_storage_table.main.name
    log_analytics_workspace = azurerm_log_analytics_workspace.main.name
  }
}

output "storage_connection_info" {
  description = "Storage connection information"
  value = {
    storage_account = azurerm_storage_account.main.name
    table_name     = azurerm_storage_table.main.name
  }
}

output "ssh_private_key" {
  description = "SSH private key for VM access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "connection_info" {
  description = "Connection information for administrators"
  value = {
    load_balancer_url = "http://${azurerm_public_ip.lb_public_ip.ip_address}"
    key_vault_uri     = azurerm_key_vault.main.vault_uri
    
    vm_access = {
      web_vms = {
        for i, vm in azurerm_linux_virtual_machine.web : 
        vm.name => azurerm_network_interface.web[i].ip_configuration[0].private_ip_address
      }
      app_vms = {
        for i, vm in azurerm_linux_virtual_machine.app : 
        vm.name => azurerm_network_interface.app[i].ip_configuration[0].private_ip_address
      }
      db_vms = {
        for i, vm in azurerm_linux_virtual_machine.db : 
        vm.name => azurerm_network_interface.db[i].ip_configuration[0].private_ip_address
      }
    }
    
    ssh_instructions = "Use SSH with the provided private key: ssh -i ssh_key.pem ${var.admin_username}@<vm_ip>"
  }
}

output "deployment_summary" {
  description = "Deployment summary"
  value = {
    total_vms_created = 2 + var.backend_instance_count + var.database_instance_count
    resource_groups_created = 5
    estimated_monthly_cost = "€400-600 (development configuration)"
    
    next_steps = [
      "1. Save SSH private key from terraform output",
      "2. Configure application on VMs",
      "3. Test load balancer connectivity",
      "4. Set up monitoring dashboards"
    ]
  }
}