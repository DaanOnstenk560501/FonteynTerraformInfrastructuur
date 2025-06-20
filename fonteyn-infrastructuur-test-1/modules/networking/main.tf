# Resource Group voor alle netwerk componenten
resource "azurerm_resource_group" "network" {
  name     = "${var.project_name}-network-rg"
  location = var.location
  tags     = var.tags
}

# Het hoofdnetwerk (Virtual Network)
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

# Subnet voor webservers (frontend)
resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.frontend_subnet_prefix]
}

# Subnet voor applicatie servers (backend)
resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.backend_subnet_prefix]
}

# Subnet voor database
resource "azurerm_subnet" "database" {
  name                 = "snet-database"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.database_subnet_prefix]
}

# Beveiligingsregels voor frontend (webservers)
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  # Sta HTTP verkeer toe (poort 80)
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

  # Sta HTTPS verkeer toe (poort 443)
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

  tags = var.tags
}

# Beveiligingsregels voor backend (app servers)
resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  # Alleen verkeer vanaf frontend subnet toestaan
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

  tags = var.tags
}

# Koppel beveiligingsregels aan subnets
resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}