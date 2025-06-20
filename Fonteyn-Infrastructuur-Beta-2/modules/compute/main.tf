# Resource Group voor compute resources
resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-compute"
  location = var.location
  tags     = var.tags
}

# Public IP voor Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "pip-${var.project_name}-lb"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Load Balancer voor frontend servers
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

# Health probe
resource "azurerm_lb_probe" "frontend" {
  loadbalancer_id = azurerm_lb.frontend.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

# Load balancer rule
resource "azurerm_lb_rule" "frontend" {
  loadbalancer_id                = azurerm_lb.frontend.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  probe_id                       = azurerm_lb_probe.frontend.id
}

# Availability Set voor web servers
resource "azurerm_availability_set" "web" {
  name                = "avset-web"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  tags                = var.tags
}

# Availability Set voor app servers
resource "azurerm_availability_set" "app" {
  name                = "avset-app"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  tags                = var.tags
}

# Network Interfaces voor web servers
resource "azurerm_network_interface" "web" {
  count               = 2
  name                = "nic-web-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.frontend_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Network Interface Backend Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.frontend.id
}

# Network Interfaces voor app servers
resource "azurerm_network_interface" "app" {
  count               = 2
  name                = "nic-app-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.backend_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Network Interface voor database server
resource "azurerm_network_interface" "db" {
  name                = "nic-db-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.database_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Web Servers (vm-web-01, vm-web-02)
resource "azurerm_linux_virtual_machine" "web" {
  count               = 2
  name                = "vm-web-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.vm_size_web
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.web.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
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
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role = "webserver"
  })
}

# App Servers (vm-app-01, vm-app-02)
resource "azurerm_linux_virtual_machine" "app" {
  count               = 2
  name                = "vm-app-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.vm_size_app
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.app.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
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
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role = "appserver"
  })
}

# Database Server (vm-db-01)
resource "azurerm_linux_virtual_machine" "db" {
  name                = "vm-db-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  size                = var.vm_size_db
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.db.id,
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
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  tags = merge(var.tags, {
    Role = "database"
  })
}