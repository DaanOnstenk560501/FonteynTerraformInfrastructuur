# Define server roles as a map for easier iteration
# This map will now correctly include 'appserver' as a VM to be created
locals {
  server_roles = {
    "appserver"  = {} # Now included for creation by this Terraform config
    "database"   = {}
    "fileserver" = {}
    # "webserver"  = {} # Still excluded to adhere to 4 VM limit
    # "printserver" = {} # Still excluded to adhere to 4 VM limit
  }
}

resource "azurerm_network_interface" "servers_nic" {
  for_each            = local.server_roles
  name                = "nic-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-${each.key}"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.server_private_ips[each.key]
  }
  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "servers" {
  for_each              = local.server_roles
  name                  = "vm-${each.key}-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  size                  = local.vm_size_standard # This will resolve to "Standard_B1s"
  admin_username        = var.admin_username
  admin_password        = random_password.admin_password.result
  network_interface_ids = [azurerm_network_interface.servers_nic[each.key].id]

  # Computer name must be 15 characters or less
  computer_name         = substr("vm-${each.key}", 0, 15)
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.storage_type
    disk_size_gb         = 128 # Adjust as needed
  }

  source_image_reference {
    publisher = var.windows_server_image_publisher
    offer     = var.windows_server_image_offer
    sku       = var.windows_server_image_sku
    version   = var.windows_server_image_version
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }
  tags = local.common_tags
}

# Workstation VM (This is the fourth new VM created by this configuration)
resource "azurerm_network_interface" "workstation_nic" {
  name                = "nic-workstation-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-workstation"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.server_private_ips["workstation"]
  }
  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "workstation" {
  name                  = "vm-workstation-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  size                  = local.vm_size_workstation # This will resolve to "Standard_B1s"
  admin_username        = var.admin_username
  admin_password        = random_password.admin_password.result
  network_interface_ids = [azurerm_network_interface.workstation_nic.id]

  # Computer name must be 15 characters or less
  computer_name         = substr("vm-workstation", 0, 15)

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = local.storage_type
    disk_size_gb         = 128 # Adjust as needed
  }

  source_image_reference {
    publisher = var.windows_server_image_publisher
    offer     = var.windows_server_image_offer
    sku       = var.windows_server_image_sku
    version   = var.windows_server_image_version
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }
  tags = local.common_tags
}