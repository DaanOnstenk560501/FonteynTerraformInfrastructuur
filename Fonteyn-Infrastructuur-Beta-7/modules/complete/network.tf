# network.tf

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = var.virtual_network_address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # This name is mandatory for VPN/ExpressRoute Gateways
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_configs["gateway"].address_prefixes
}

resource "azurerm_subnet" "servers" {
  name                 = "snet-servers"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_configs["servers"].address_prefixes
}

resource "azurerm_subnet" "workstations" {
  name                 = "snet-workstations"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_configs["workstations"].address_prefixes
}