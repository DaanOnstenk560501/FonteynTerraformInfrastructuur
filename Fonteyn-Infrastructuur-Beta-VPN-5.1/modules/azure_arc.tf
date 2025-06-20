# azure_arc.tf - Azure Arc for Hybrid Server Management

# Only create Arc resources if enabled
locals {
  create_arc_resources = var.enable_azure_arc
}

# Resource group for Azure Arc resources
resource "azurerm_resource_group" "azure_arc" {
  count    = local.create_arc_resources ? 1 : 0
  name     = "rg-${var.project_name}-arc-${var.environment}"
  location = var.location
  
  tags = merge(local.common_tags, {
    Purpose = "azure-arc-hybrid-management"
  })
}

# Log Analytics workspace for Azure Arc monitoring
resource "azurerm_log_analytics_workspace" "azure_arc" {
  count               = local.create_arc_resources ? 1 : 0
  name                = "law-${var.project_name}-arc-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.azure_arc[0].name
  sku                 = "PerGB2018"
  retention_in_days   = 30  # Reduced for testing
  
  tags = local.common_tags
}

# Service Principal for Azure Arc (User Assigned Identity)
resource "azurerm_user_assigned_identity" "azure_arc" {
  count               = local.create_arc_resources ? 1 : 0
  name                = "id-${var.project_name}-arc-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.azure_arc[0].name
  
  tags = local.common_tags
}

# Role assignments for Azure Arc service principal
resource "azurerm_role_assignment" "azure_arc_connected_machine" {
  count                = local.create_arc_resources ? 1 : 0
  scope                = azurerm_resource_group.azure_arc[0].id
  role_definition_name = "Azure Connected Machine Resource Administrator"
  principal_id         = azurerm_user_assigned_identity.azure_arc[0].principal_id
}

resource "azurerm_role_assignment" "azure_arc_monitoring" {
  count                = local.create_arc_resources ? 1 : 0
  scope                = azurerm_log_analytics_workspace.azure_arc[0].id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.azure_arc[0].principal_id
}

# Data Collection Rule for Azure Arc monitoring
resource "azurerm_monitor_data_collection_rule" "azure_arc" {
  count               = local.create_arc_resources ? 1 : 0
  name                = "dcr-${var.project_name}-arc-${var.environment}"
  resource_group_name = azurerm_resource_group.azure_arc[0].name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.azure_arc[0].id
      name                  = "log-analytics-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["log-analytics-destination"]
  }

  data_sources {
    syslog {
      facility_names = ["*"]
      log_levels     = ["*"]
      name           = "syslog-data-source"
    }

    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(_Total)\\% Free Space"
      ]
      name = "perf-data-source"
    }
  }

  tags = local.common_tags
}

# Azure Policy for Arc server compliance
resource "azurerm_resource_group_policy_assignment" "arc_monitoring" {
  count                = local.create_arc_resources ? 1 : 0
  name                 = "arc-monitoring-policy"
  resource_group_id    = azurerm_resource_group.azure_arc[0].id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/842e54e8-9ce9-4b39-9223-c7e8470c8aed"

  display_name = "Enable Azure Monitor for Arc servers in ${var.project_name}"
  description  = "Ensures all Arc-enabled servers have monitoring configured"

  parameters = jsonencode({
    logAnalyticsWorkspace = {
      value = azurerm_log_analytics_workspace.azure_arc[0].id
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

# Management subnet for Arc management VM (optional)
resource "azurerm_subnet" "management" {
  name                 = "subnet-management"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Network Security Group for management subnet
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow RDP/WinRM from on-premises for Arc management
  security_rule {
    name                       = "AllowRDPFromOnPrem"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.hoofdkantoor_networks
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWinRMFromOnPrem"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefixes    = var.hoofdkantoor_networks
    destination_address_prefix = "*"
  }

  # Allow SSH from on-premises
  security_rule {
    name                       = "AllowSSHFromOnPrem"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.hoofdkantoor_networks
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with management subnet
resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# Optional: Arc management VM for hybrid operations
resource "azurerm_network_interface" "arc_management" {
  count               = local.create_arc_resources && var.create_arc_management_vm ? 1 : 0
  name                = "nic-arc-mgmt-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "arc_management" {
  count               = local.create_arc_resources && var.create_arc_management_vm ? 1 : 0
  name                = "vm-arc-mgmt-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  admin_password      = random_password.arc_admin[0].result

  network_interface_ids = [
    azurerm_network_interface.arc_management[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-smalldisk-g2"
    version   = "latest"
  }

  tags = merge(local.common_tags, {
    Role = "arc-management"
    Tier = "management"
  })
}

# Random password for Arc management VM
resource "random_password" "arc_admin" {
  count   = local.create_arc_resources && var.create_arc_management_vm ? 1 : 0
  length  = 16
  special = true
}