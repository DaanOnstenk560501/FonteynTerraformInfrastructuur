# vpn.tf - On-Premises Connectivity

# Gateway subnet for VPN Gateway (required)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Name must be exactly "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.255.0/27"]  # /27 is minimum for gateway subnet
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpn-gateway-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.common_tags
}

# Virtual Network Gateway (VPN Gateway)
resource "azurerm_virtual_network_gateway" "main" {
  name                = "vgw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = false
  sku           = var.vpn_gateway_sku  # VpnGw1 for testing, VpnGw2+ for production

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.common_tags
}

# Local Network Gateway - Hoofdkantoor (Head Office)
resource "azurerm_local_network_gateway" "hoofdkantoor" {
  name                = "lgw-hoofdkantoor-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = var.hoofdkantoor_public_ip
  address_space       = var.hoofdkantoor_networks

  tags = merge(local.common_tags, {
    Site = "hoofdkantoor"
  })
}

# VPN Connection - Hoofdkantoor
resource "azurerm_virtual_network_gateway_connection" "hoofdkantoor" {
  name                = "cn-hoofdkantoor-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.hoofdkantoor.id

  shared_key = var.vpn_shared_key

  tags = merge(local.common_tags, {
    Site = "hoofdkantoor"
  })
}

# Local Network Gateway - Vakantiepark NL (if enabled)
resource "azurerm_local_network_gateway" "vakantiepark_nl" {
  count               = var.enable_vakantiepark_nl ? 1 : 0
  name                = "lgw-vakantiepark-nl-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = var.vakantiepark_nl_public_ip
  address_space       = var.vakantiepark_nl_networks

  tags = merge(local.common_tags, {
    Site = "vakantiepark-nl"
  })
}

# VPN Connection - Vakantiepark NL
resource "azurerm_virtual_network_gateway_connection" "vakantiepark_nl" {
  count               = var.enable_vakantiepark_nl ? 1 : 0
  name                = "cn-vakantiepark-nl-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.vakantiepark_nl[0].id

  shared_key = var.vpn_shared_key

  tags = merge(local.common_tags, {
    Site = "vakantiepark-nl"
  })
}

# Route Table for on-premises traffic
resource "azurerm_route_table" "onprem_routes" {
  name                = "rt-onprem-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Route to hoofdkantoor networks via VPN
  route {
    name           = "hoofdkantoor"
    address_prefix = var.hoofdkantoor_networks[0]  # Primary network
    next_hop_type  = "VirtualNetworkGateway"
  }

  # Route to vakantiepark NL (if enabled)
  dynamic "route" {
    for_each = var.enable_vakantiepark_nl ? [1] : []
    content {
      name           = "vakantiepark-nl"
      address_prefix = var.vakantiepark_nl_networks[0]
      next_hop_type  = "VirtualNetworkGateway"
    }
  }

  tags = local.common_tags
}

# Associate route table with backend subnet (where servers need on-prem access)
resource "azurerm_subnet_route_table_association" "backend" {
  subnet_id      = azurerm_subnet.backend.id
  route_table_id = azurerm_route_table.onprem_routes.id
}

# Associate route table with database subnet
resource "azurerm_subnet_route_table_association" "database" {
  subnet_id      = azurerm_subnet.database.id
  route_table_id = azurerm_route_table.onprem_routes.id
}

# DNS Configuration for hybrid connectivity
resource "azurerm_private_dns_zone" "fonteyn_corp" {
  name                = "fonteyn.corp"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "dns-link-${var.project_name}-${var.environment}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.fonteyn_corp.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = true

  tags = local.common_tags
}

# DNS records for on-premises servers (examples)
resource "azurerm_private_dns_a_record" "fontdc01" {
  name                = "fontdc01"
  zone_name           = azurerm_private_dns_zone.fonteyn_corp.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["192.168.2.100"]  # Your DC IP

  tags = local.common_tags
}

resource "azurerm_private_dns_a_record" "fontdc02" {
  name                = "fontdc02"
  zone_name           = azurerm_private_dns_zone.fonteyn_corp.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["192.168.2.99"]   # Your DC IP

  tags = local.common_tags
}

# Network Security Group rules for on-premises connectivity
resource "azurerm_network_security_rule" "allow_onprem_management" {
  name                        = "AllowOnPremManagement"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.hoofdkantoor_networks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.backend.name
}

resource "azurerm_network_security_rule" "allow_onprem_database" {
  name                        = "AllowOnPremDatabase"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["3306", "5432", "1433"]  # MySQL, PostgreSQL, SQL Server
  source_address_prefixes     = var.hoofdkantoor_networks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database.name
}