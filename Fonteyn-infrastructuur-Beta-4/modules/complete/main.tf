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
# STORAGE RESOURCES - ENTERPRISE LEVEL (FIXED NAMING)
# ==============================================================================

resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.project_name}-storage"
  location = var.location
  tags     = local.common_tags
}

# Primary Storage Account - FIXED naming and network rules
resource "azurerm_storage_account" "main" {
  name                     = "stfonteyn${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Premium"
  account_replication_type = "ZRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
  
  blob_properties {
    delete_retention_policy {
      days = 30
    }
    versioning_enabled = true
    change_feed_enabled = true
  }

  network_rules {
    default_action = "Allow"  # FIXED: Changed from Deny
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.frontend.id,
      azurerm_subnet.backend.id,
      azurerm_subnet.management.id
    ]
    
    # FIXED: Removed private IP rules - not supported
  }

  tags = local.common_tags
}

# Diagnostics Storage Account - FIXED naming
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"

  tags = local.common_tags
}

# Backup Storage Account - FIXED naming
resource "azurerm_storage_account" "backup" {
  name                     = "stbackup${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"

  tags = local.common_tags
}

# File Shares voor enterprise applications
resource "azurerm_storage_share" "application_files" {
  name                 = "${var.project_name}-application-files"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 500
}

resource "azurerm_storage_share" "user_profiles" {
  name                 = "${var.project_name}-user-profiles"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 1000
}

# Storage Tables voor application data
resource "azurerm_storage_table" "reservations" {
  name                 = "reservations"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_table" "hrm_data" {
  name                 = "hrmdata"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_table" "monitoring_logs" {
  name                 = "monitoringlogs"
  storage_account_name = azurerm_storage_account.main.name
}

# ==============================================================================
# MONITORING RESOURCES - ENTERPRISE LEVEL
# ==============================================================================

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${var.project_name}-monitoring"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace - Enterprise configuration
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = local.common_tags
}

# Application Insights voor web applications
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Application Insights voor reserveringssysteem
resource "azurerm_application_insights" "reservations" {
  name                = "ai-${var.project_name}-reservations"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Application Insights voor HRM systeem
resource "azurerm_application_insights" "hrm" {
  name                = "ai-${var.project_name}-hrm"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Action Groups voor alerting
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-${var.project_name}-critical"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "critical"

  email_receiver {
    name          = "admin"
    email_address = "560501@student.fontys.nl"
  }

  email_receiver {
    name          = "it-team"
    email_address = "it-team@fonteyn.corp"  # Placeholder
  }

  sms_receiver {
    name         = "emergency"
    country_code = "31"
    phone_number = "0612345678"  # Placeholder
  }

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "warning" {
  name                = "ag-${var.project_name}-warning"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "warning"

  email_receiver {
    name          = "admin"
    email_address = "560501@student.fontys.nl"
  }

  tags = local.common_tags
}

# Recovery Services Vault
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  cross_region_restore_enabled = true

  tags = local.common_tags
}

# ==============================================================================
# AZURE ARC CONFIGURATION - HYBRID CLOUD MANAGEMENT
# ==============================================================================

resource "azurerm_resource_group" "azure_arc" {
  name     = "rg-${var.project_name}-arc"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace voor Azure Arc (dedicated)
resource "azurerm_log_analytics_workspace" "azure_arc" {
  name                = "law-${var.project_name}-arc"
  location            = azurerm_resource_group.azure_arc.location
  resource_group_name = azurerm_resource_group.azure_arc.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = merge(local.common_tags, {
    Purpose = "azure-arc-hybrid-management"
  })
}

# Service Principal voor Azure Arc
resource "azurerm_user_assigned_identity" "azure_arc" {
  name                = "id-${var.project_name}-arc"
  location            = azurerm_resource_group.azure_arc.location
  resource_group_name = azurerm_resource_group.azure_arc.name

  tags = local.common_tags
}

# Role assignments voor Azure Arc service principal
resource "azurerm_role_assignment" "azure_arc_contributor" {
  scope                = azurerm_resource_group.azure_arc.id
  role_definition_name = "Azure Connected Machine Resource Administrator"
  principal_id         = azurerm_user_assigned_identity.azure_arc.principal_id
}

resource "azurerm_role_assignment" "azure_arc_monitoring" {
  scope                = azurerm_log_analytics_workspace.azure_arc.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.azure_arc.principal_id
}

# ==============================================================================
# AZURE POLICY ASSIGNMENTS - GOVERNANCE (FIXED)
# ==============================================================================

# Policy Assignment voor VM compliance monitoring - FIXED parameters
resource "azurerm_resource_group_policy_assignment" "vm_monitoring" {
  name                 = "vm-monitoring-policy"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0868462e-646c-4fe3-9ced-a733534b6a2c"

  display_name = "Enable Azure Monitor for VMs in ${var.project_name}"
  description  = "Ensures all VMs have Azure Monitor enabled for compliance"

  parameters = jsonencode({
    logAnalytics = {  # FIXED: Correct parameter name
      value = azurerm_log_analytics_workspace.main.id
    }
  })
  identity {
    type = "SystemAssigned"
  }
}

# Policy Assignment voor disk encryption - FIXED parameters
resource "azurerm_resource_group_policy_assignment" "disk_encryption" {
  name                 = "disk-encryption-policy"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0473574d-2d43-4217-aefe-941fcdf7e684"

  display_name = "Require disk encryption for ${var.project_name} VMs"
  description  = "Ensures all VM disks are encrypted for security compliance"

  parameters = jsonencode({
    listOfAllowedLocations = {  # FIXED: Required parameter added
      value = [var.location]
    }
  })
}

# ==============================================================================
# AUTOMATION & RUNBOOKS - OPERATIONAL EXCELLENCE
# ==============================================================================

resource "azurerm_automation_account" "main" {
  name                = "aa-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku_name            = "Basic"

  tags = local.common_tags
}

# Link Automation Account to Log Analytics
resource "azurerm_log_analytics_linked_service" "automation" {
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  read_access_id      = azurerm_automation_account.main.id
}

# Update Management Solution
resource "azurerm_log_analytics_solution" "updates" {
  solution_name         = "Updates"
  location              = azurerm_resource_group.monitoring.location
  resource_group_name   = azurerm_resource_group.monitoring.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }
}

# ==============================================================================
# BACKUP CONFIGURATION - AZURE SITE RECOVERY ENHANCED
# ==============================================================================

# Backup Policy voor VMs
resource "azurerm_backup_policy_vm" "daily" {
  name                = "backup-policy-daily"
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}

# ==============================================================================
# COMPUTE RESOURCES - ENTERPRISE ARCHITECTURE
# ==============================================================================

resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-compute"
  location = var.location
  tags     = local.common_tags
}

# DMZ Load Balancer - Public facing
resource "azurerm_public_ip" "dmz_lb_public_ip" {
  name                = "pip-${var.project_name}-dmz-lb"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_lb" "dmz" {
  name                = "lb-${var.project_name}-dmz"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "DMZ-PublicIP"
    public_ip_address_id = azurerm_public_ip.dmz_lb_public_ip.id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "dmz" {
  loadbalancer_id = azurerm_lb.dmz.id
  name            = "DMZ-BackendPool"
}

resource "azurerm_lb_probe" "dmz_https" {
  loadbalancer_id = azurerm_lb.dmz.id
  name            = "https-probe"
  port            = 443
  protocol        = "Https"
  request_path    = "/health"
}

resource "azurerm_lb_rule" "dmz_https" {
  loadbalancer_id                = azurerm_lb.dmz.id
  name                           = "HTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "DMZ-PublicIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dmz.id]
  probe_id                      = azurerm_lb_probe.dmz_https.id
}

resource "azurerm_lb_rule" "dmz_http_redirect" {
  loadbalancer_id                = azurerm_lb.dmz.id
  name                           = "HTTP-Redirect"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "DMZ-PublicIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dmz.id]
}

# Internal Load Balancer voor backend services
resource "azurerm_lb" "internal" {
  name                = "lb-${var.project_name}-internal"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "Internal-Frontend"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "internal" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "Internal-BackendPool"
}

resource "azurerm_lb_probe" "internal_app" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "app-probe"
  port            = 8080
  protocol        = "Http"
  request_path    = "/health"
}

resource "azurerm_lb_rule" "internal_app" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "Application"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "Internal-Frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal.id]
  probe_id                      = azurerm_lb_probe.internal_app.id
}

# Availability Sets - Enterprise HA
resource "azurerm_availability_set" "web" {
  name                = "avset-web"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

resource "azurerm_availability_set" "app" {
  name                = "avset-app"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

resource "azurerm_availability_set" "database" {
  name                = "avset-database"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

# Network Interfaces - FIXED with explicit dependencies
resource "azurerm_network_interface" "web" {
  count               = var.frontend_instance_count
  name                = "nic-web-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.frontend]
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

  depends_on = [azurerm_subnet.backend]
  tags = local.common_tags
}

resource "azurerm_network_interface" "database" {
  count               = var.database_instance_count
  name                = "nic-db-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.database]
  tags = local.common_tags
}

resource "azurerm_network_interface" "monitoring" {
  name                = "nic-monitoring-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.management]
  tags = local.common_tags
}

resource "azurerm_network_interface" "printserver" {
  name                = "nic-printserver-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.management]
  tags = local.common_tags
}

resource "azurerm_network_interface" "azure_arc" {
  name                = "nic-azure-arc-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azure_arc.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.azure_arc]
  tags = local.common_tags
}

# Load Balancer Associations
resource "azurerm_network_interface_backend_address_pool_association" "web_dmz" {
  count                   = var.frontend_instance_count
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.dmz.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app_internal" {
  count                   = var.backend_instance_count
  network_interface_id    = azurerm_network_interface.app[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal.id
}

# ==============================================================================
# VIRTUAL MACHINES - ENTERPRISE CONFIGURATION
# ==============================================================================

# Frontend Web Servers
resource "azurerm_linux_virtual_machine" "web" {
  count               = var.frontend_instance_count
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
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
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
    Role        = "webserver"
    Tier        = "frontend"
    Application = "nginx-apache"
  })
}

# Data disks voor web servers
resource "azurerm_managed_disk" "web_data" {
  count                = var.frontend_instance_count
  name                 = "disk-web-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "web_data" {
  count              = var.frontend_instance_count
  managed_disk_id    = azurerm_managed_disk.web_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.web[count.index].id
  lun                = "0"
  caching            = "ReadOnly"
}

# Backend Application Servers
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
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
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
    Role        = "appserver"
    Tier        = "backend"
    Application = "reservations-hrm"
  })
}

# Data disks voor app servers
resource "azurerm_managed_disk" "app_data" {
  count                = var.backend_instance_count
  name                 = "disk-app-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_data" {
  count              = var.backend_instance_count
  managed_disk_id    = azurerm_managed_disk.app_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.app[count.index].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Database Servers
resource "azurerm_linux_virtual_machine" "database" {
  count               = var.database_instance_count
  name                = "vm-db-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.database_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.database.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.database[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
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
    Role        = "database"
    Tier        = "data"
    Application = "mysql-postgresql"
  })
}

# Database data disks
resource "azurerm_managed_disk" "database_data" {
  count                = var.database_instance_count
  name                 = "disk-db-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "database_data" {
  count              = var.database_instance_count
  managed_disk_id    = azurerm_managed_disk.database_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Database log disks
resource "azurerm_managed_disk" "database_log" {
  count                = var.database_instance_count
  name                 = "disk-db-${format("%02d", count.index + 1)}-log"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "database_log" {
  count              = var.database_instance_count
  managed_disk_id    = azurerm_managed_disk.database_log[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  lun                = "1"
  caching            = "None"
}

# Monitoring Server
resource "azurerm_linux_virtual_machine" "monitoring" {
  name                = "vm-monitoring-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.monitoring_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.monitoring.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
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
    Role        = "monitoring"
    Tier        = "management"
    Application = "azure-monitor-grafana"
  })
}

# Monitoring data disk
resource "azurerm_managed_disk" "monitoring_data" {
  name                 = "disk-monitoring-01-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "monitoring_data" {
  managed_disk_id    = azurerm_managed_disk.monitoring_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.monitoring.id
  lun                = "0"
  caching            = "ReadWrite"
}

# Print Server
resource "azurerm_windows_virtual_machine" "printserver" {
  name                = "vm-printserv-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.printserver_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.sql_admin.result

  network_interface_ids = [
    azurerm_network_interface.printserver.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "printserver"
    Tier        = "management"
    Application = "windows-print-services"
  })
}

# Azure Arc Management Server
resource "azurerm_windows_virtual_machine" "azure_arc" {
  name                = "vm-azarc-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.monitoring_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.sql_admin.result

  network_interface_ids = [
    azurerm_network_interface.azure_arc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "azure-arc"
    Tier        = "management"
    Application = "hybrid-management"
  })
}

# Protected VM Backup Items (voor kritieke VMs)
resource "azurerm_backup_protected_vm" "database" {
  count               = var.database_instance_count
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.database[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

resource "azurerm_backup_protected_vm" "monitoring" {
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.monitoring.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# ==============================================================================
# MONITORING ALERTS - ENTERPRISE LEVEL (FIXED)
# ==============================================================================

# CPU Alert voor alle VMs - FIXED with target_resource_type
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "alert-${var.project_name}-high-cpu"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_resource_group.compute.id]
  description         = "Alert when CPU usage is higher than 80%"
  target_resource_type = "Microsoft.Compute/virtualMachines"  # FIXED: Added target type
  target_resource_location = var.location                     # FIXED: Added target location

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  frequency   = "PT5M"
  window_size = "PT15M"
  severity    = 2

  tags = local.common_tags
}

# Memory Alert voor Database VMs - FIXED
resource "azurerm_monitor_metric_alert" "high_memory" {
  name                = "alert-${var.project_name}-high-memory"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes = [
    for vm in azurerm_linux_virtual_machine.database : vm.id
  ]
  description = "Alert when memory usage is higher than 85%"
  target_resource_type = "Microsoft.Compute/virtualMachines"  # FIXED: Added target type
  target_resource_location = var.location                     # FIXED: Added target location

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  frequency   = "PT5M"
  window_size = "PT15M"
  severity    = 1

  tags = local.common_tags
}

# VPN Alert removed - TunnelState metric not available in all regions

# ==============================================================================
# OUTPUTS - COMPREHENSIVE ENTERPRISE DEPLOYMENT INFORMATION
# ==============================================================================

output "deployment_information" {
  description = "Complete deployment information for Fonteyn Enterprise"
  value = {
    project_details = {
      name         = var.project_name
      environment  = var.environment
      location     = var.location
      deployed_at  = timestamp()
      terraform_version = "managed-by-terraform"
    }

    network_configuration = {
      azure_vnet = {
        name          = azurerm_virtual_network.azure_enterprise.name
        address_space = var.azure_vnet_address_space
        resource_group = azurerm_resource_group.network.name
      }
      
      subnets = {
        dmz         = var.dmz_subnet_prefix
        frontend    = var.frontend_subnet_prefix
        backend     = var.backend_subnet_prefix
        database    = var.database_subnet_prefix
        management  = var.management_subnet_prefix
        azure_arc   = var.azure_arc_subnet_prefix
        gateway     = "10.0.255.0/27"
        firewall    = "10.0.254.0/26"
      }

      vpn_gateway = {
        public_ip    = azurerm_public_ip.vpn_gateway.ip_address
        gateway_name = azurerm_virtual_network_gateway.vpn.name
        sku         = "VpnGw2"
        generation  = "Generation2"
      }

      load_balancers = {
        dmz_public_ip = azurerm_public_ip.dmz_lb_public_ip.ip_address
        internal_ip   = azurerm_lb.internal.frontend_ip_configuration[0].private_ip_address
      }
    }

    virtual_machines = {
      web_servers = {
        count = var.frontend_instance_count
        size  = var.frontend_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.web : azurerm_network_interface.web[index(azurerm_linux_virtual_machine.web, vm)].ip_configuration[0].private_ip_address]
      }
      
      app_servers = {
        count = var.backend_instance_count
        size  = var.backend_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.app : azurerm_network_interface.app[index(azurerm_linux_virtual_machine.app, vm)].ip_configuration[0].private_ip_address]
      }
      
      database_servers = {
        count = var.database_instance_count
        size  = var.database_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.database : azurerm_network_interface.database[index(azurerm_linux_virtual_machine.database, vm)].ip_configuration[0].private_ip_address]
      }

      management_servers = {
        monitoring = {
          ip   = azurerm_network_interface.monitoring.ip_configuration[0].private_ip_address
          size = var.monitoring_vm_size
        }
        print_server = {
          ip   = azurerm_network_interface.printserver.ip_configuration[0].private_ip_address
          size = var.printserver_vm_size
        }
        azure_arc = {
          ip   = azurerm_network_interface.azure_arc.ip_configuration[0].private_ip_address
          size = var.monitoring_vm_size
        }
      }
    }

    security_and_storage = {
      key_vault = {
        name = azurerm_key_vault.main.name
        uri  = azurerm_key_vault.main.vault_uri
      }
      
      storage_accounts = {
        main        = azurerm_storage_account.main.name
        diagnostics = azurerm_storage_account.diagnostics.name
        backup      = azurerm_storage_account.backup.name
      }

      backup_vault = azurerm_recovery_services_vault.main.name
    }

    monitoring_and_management = {
      log_analytics = {
        main      = azurerm_log_analytics_workspace.main.name
        azure_arc = azurerm_log_analytics_workspace.azure_arc.name
      }
      
      application_insights = {
        main         = azurerm_application_insights.main.name
        reservations = azurerm_application_insights.reservations.name
        hrm          = azurerm_application_insights.hrm.name
      }

      automation_account = azurerm_automation_account.main.name
      
      action_groups = {
        critical = azurerm_monitor_action_group.critical.name
        warning  = azurerm_monitor_action_group.warning.name
      }
    }

    hybrid_cloud_integration = {
      azure_arc = {
        resource_group      = azurerm_resource_group.azure_arc.name
        identity_name       = azurerm_user_assigned_identity.azure_arc.name
        log_analytics       = azurerm_log_analytics_workspace.azure_arc.name
      }

      on_premises_connectivity = {
        networks = var.on_premises_networks
        dns_servers = var.on_premises_dns_servers
        gateway_ip = var.hoofdkantoor_gateway_ip
      }
    }
  }
}

output "connection_information" {
  description = "How to connect to and manage the infrastructure"
  value = {
    web_access = {
      public_url = "https://${azurerm_public_ip.dmz_lb_public_ip.ip_address}"
      load_balancer = "DMZ Load Balancer with SSL termination"
    }

    vm_access = {
      ssh_key_location = "Use terraform output ssh_private_key"
      jump_host = "Connect via management subnet or VPN"
      
      connection_examples = {
        web_server = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}"
        database   = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.database[0].ip_configuration[0].private_ip_address}"
        monitoring = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.monitoring.ip_configuration[0].private_ip_address}"
      }
    }

    management_access = {
      azure_portal = "https://portal.azure.com"
      key_vault = azurerm_key_vault.main.vault_uri
      log_analytics = "Search for: ${azurerm_log_analytics_workspace.main.name}"
    }

    vpn_configuration = {
      azure_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
      shared_key_location = "Key Vault secret: vpn-shared-key-hoofdkantoor"
      local_networks = var.on_premises_networks
      
      pfsense_setup = {
        remote_gateway = azurerm_public_ip.vpn_gateway.ip_address
        local_networks = var.on_premises_networks
        azure_networks = [var.azure_vnet_address_space]
        protocol = "IKEv2"
        encryption = "AES-256"
      }
    }
  }
}

output "next_steps" {
  description = "Post-deployment configuration steps"
  value = {
    immediate_tasks = [
      "1. Save SSH private key: terraform output -raw ssh_private_key > ssh_key.pem",
      "2. Set SSH key permissions: chmod 600 ssh_key.pem",
      "3. Configure pfSense VPN with Azure gateway IP: ${azurerm_public_ip.vpn_gateway.ip_address}",
      "4. Test VPN connectivity between Azure and on-premises",
      "5. Install Azure Arc agent on on-premises servers"
    ]

    azure_arc_setup = [
      "1. Download Azure Arc installation script from Azure portal",
      "2. Run on FONTDC01 (192.168.2.100) and FONTDC02 (192.168.2.99)",
      "3. Install on file server and print server (VLAN B)",
      "4. Configure monitoring and policy compliance"
    ]

    application_deployment = [
      "1. Configure web servers with Nginx/Apache",
      "2. Deploy reservation system on app servers",
      "3. Set up database cluster (MySQL/PostgreSQL)",
      "4. Configure monitoring dashboards",
      "5. Set up backup schedules"
    ]

    security_hardening = [
      "1. Review and adjust NSG rules",
      "2. Configure Azure AD Connect for identity sync",
      "3. Enable Azure Security Center recommendations",
      "4. Set up certificate management for SSL",
      "5. Configure audit logging"
    ]

    cost_optimization = [
      "1. Monitor resource utilization",
      "2. Consider scaling down non-production VMs",
      "3. Set up budget alerts",
      "4. Review storage account tiers",
      "5. Optimize backup retention policies"
    ]

    future_expansions = [
      "1. Add vakantiepark NL gateway and connectivity",
      "2. Add vakantiepark BE gateway and connectivity", 
      "3. Add vakantiepark DE gateway and connectivity",
      "4. Implement Azure Firewall for enhanced security",
      "5. Consider Azure Virtual Desktop for remote workers"
    ]
  }
}

output "ssh_private_key" {
  description = "SSH private key for VM access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "cost_information" {
  description = "Cost optimization and monitoring information"
  value = {
    current_configuration = "Testing/Development optimized"
    estimated_monthly_cost = "€200-400 (with testing VM sizes)"
    enterprise_monthly_cost = "€2,500-4,000 (with enterprise VM sizes)"
    
    cost_drivers = {
      largest_costs = ["Virtual Machines", "VPN Gateway", "Storage Accounts", "Load Balancers"]
      optimization_opportunities = ["Right-size VMs", "Reserved Instances", "Storage tiers"]
    }

    monitoring = {
      cost_alerts = "Set up in Azure portal under Cost Management"
      budgets = "Configure monthly spending limits"
      recommendations = "Review Azure Advisor cost recommendations"
    }
  }
}

# Generate SSH key pair for VM access
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# VPN Gateway Public IP
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-${var.project_name}-vpn-gw"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}