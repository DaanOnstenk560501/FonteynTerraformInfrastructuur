# network.tf - Network Configuration for Windows VMs
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = local.common_tags
}

# Frontend subnet for web servers
resource "azurerm_subnet" "frontend" {
  name                 = "subnet-frontend"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Backend subnet for app servers
resource "azurerm_subnet" "backend" {
  name                 = "subnet-backend"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Database subnet
resource "azurerm_subnet" "database" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Network Security Groups for Windows VMs
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow HTTP and HTTPS from internet
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

  # Allow RDP for Windows VMs (restrict to specific IP ranges in production!)
  security_rule {
    name                       = "AllowRDP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  # Allow WinRM for remote management
  security_rule {
    name                       = "AllowWinRM"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow app traffic from frontend (port 8080 for .NET app)
  security_rule {
    name                       = "AllowAppTraffic"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow RDP from frontend subnet and management
  security_rule {
    name                       = "AllowRDPFromFrontend"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = ["10.0.1.0/24"]
    destination_address_prefix = "*"
  }

  # Allow RDP from management IPs
  security_rule {
    name                       = "AllowRDPFromManagement"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  # Allow WinRM for remote management
  security_rule {
    name                       = "AllowWinRMFromSubnet"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow WinRM from management IPs (separate rule)
  security_rule {
    name                       = "AllowWinRMFromManagement"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "database" {
  name                = "nsg-database"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow SQL Server from backend
  security_rule {
    name                       = "AllowSQLServer"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow SQL Server Browser from backend
  security_rule {
    name                       = "AllowSQLBrowser"
    priority                   = 1011
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1434"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow RDP from backend subnet
  security_rule {
    name                       = "AllowRDPFromBackend"
    priority                   = 1012
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow RDP from management IPs
  security_rule {
    name                       = "AllowRDPFromManagement"
    priority                   = 1013
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  # Allow WinRM for remote management
  security_rule {
    name                       = "AllowWinRMFromSubnet"
    priority                   = 1014
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow WinRM from management IPs (separate rule)
  security_rule {
    name                       = "AllowWinRMFromManagement"
    priority                   = 1015
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = contains(var.allowed_ip_ranges, "*") ? "*" : null
    source_address_prefixes    = contains(var.allowed_ip_ranges, "*") ? null : var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSGs with subnets
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

# Public IP for load balancer
resource "azurerm_public_ip" "main" {
  name                = "pip-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.common_tags
}

# Load balancer for web servers
resource "azurerm_lb" "main" {
  name                = "lb-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "main" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                      = azurerm_lb_probe.main.id
}