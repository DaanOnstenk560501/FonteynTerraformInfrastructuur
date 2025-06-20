# network.tf - Hybrid Network Configuration for Fonteyn Infrastructure

# Virtual Network with on-premises DNS configuration
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}-hybrid"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  # Critical: Use on-premises DNS servers for hybrid domain join
  dns_servers = var.onpremise_dns_servers
  
  tags = local.common_tags
}

# Subnets for three-tier architecture
resource "azurerm_subnet" "frontend" {
  name                 = "subnet-frontend"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "subnet-backend"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Gateway subnet for VPN Gateway (required for hybrid connectivity)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"  # Name must be exactly "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.255.0/27"]
}

# Network Security Groups with hybrid AD support
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend-hybrid"
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

  # Allow RDP from management networks
  security_rule {
    name                       = "AllowRDP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_ip_ranges
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
    source_address_prefixes    = var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  # Allow Active Directory traffic from on-premises
  security_rule {
    name                       = "AllowADFromOnPremises"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["53", "88", "135", "389", "445", "464", "636", "3268", "3269", "9389"]
    source_address_prefixes    = var.onpremise_address_spaces
    destination_address_prefix = "*"
  }

  # Allow ICMP for connectivity testing
  security_rule {
    name                       = "AllowICMPFromOnPremises"
    priority                   = 901
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = var.onpremise_address_spaces
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend-hybrid"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow app traffic from frontend
  security_rule {
    name                       = "AllowAppTraffic"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow RDP from frontend and management
  security_rule {
    name                       = "AllowRDPFromFrontend"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDPFromManagement"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_ip_ranges
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
    source_address_prefixes    = concat(["10.0.1.0/24"], var.allowed_ip_ranges)
    destination_address_prefix = "*"
  }

  # Allow Active Directory traffic from on-premises
  security_rule {
    name                       = "AllowADFromOnPremises"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["53", "88", "135", "389", "445", "464", "636", "3268", "3269", "9389"]
    source_address_prefixes    = var.onpremise_address_spaces
    destination_address_prefix = "*"
  }

  # Allow ICMP for connectivity testing
  security_rule {
    name                       = "AllowICMPFromOnPremises"
    priority                   = 901
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = var.onpremise_address_spaces
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "database" {
  name                = "nsg-database-hybrid"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow SQL Server from backend
  security_rule {
    name                       = "AllowSQLServer"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow SQL Browser from backend
  security_rule {
    name                       = "AllowSQLBrowser"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "1434"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow RDP from backend and management
  security_rule {
    name                       = "AllowRDPFromBackend"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDPFromManagement"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_ip_ranges
    destination_address_prefix = "*"
  }

  # Allow WinRM for remote management
  security_rule {
    name                       = "AllowWinRM"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefixes    = concat(["10.0.2.0/24"], var.allowed_ip_ranges)
    destination_address_prefix = "*"
  }

  # Allow Active Directory traffic from on-premises
  security_rule {
    name                       = "AllowADFromOnPremises"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["53", "88", "135", "389", "445", "464", "636", "3268", "3269", "9389"]
    source_address_prefixes    = var.onpremise_address_spaces
    destination_address_prefix = "*"
  }

  # Allow ICMP for connectivity testing
  security_rule {
    name                       = "AllowICMPFromOnPremises"
    priority                   = 901
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = var.onpremise_address_spaces
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
  name                = "pip-${var.project_name}-${var.environment}-lb"
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

# VPN Gateway Components for Hybrid Connectivity

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpn-gateway-${var.project_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.common_tags
}

# VPN Gateway for Site-to-Site connection to Fonteyn premises
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vpn-gateway-${var.project_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku
  
  active_active = false
  enable_bgp    = true

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  bgp_settings {
    asn = 65515  # Azure default ASN
  }

  tags = local.common_tags
}

# Local Network Gateway representing Fonteyn on-premises network
resource "azurerm_local_network_gateway" "fonteyn_onpremise" {
  name                = "lng-fonteyn-onpremise"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  gateway_address = var.onpremise_gateway_ip  # 145.220.74.133
  address_space   = var.onpremise_address_spaces

  bgp_settings {
    asn                 = var.onpremise_bgp_asn      # 65001
    bgp_peering_address = var.onpremise_bgp_peer_ip  # 192.168.2.100 (DC1)
  }

  tags = local.common_tags
}

# VPN Connection between Azure and Fonteyn premises
resource "azurerm_virtual_network_gateway_connection" "fonteyn_connection" {
  name                = "connection-fonteyn-onpremise"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.fonteyn_onpremise.id

  shared_key = var.vpn_shared_key
  enable_bgp = true

  tags = local.common_tags
}

# Route Table for directing traffic to on-premises through VPN
resource "azurerm_route_table" "hybrid" {
  name                = "rt-hybrid-${var.project_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # Route on-premise traffic through VPN Gateway
  dynamic "route" {
    for_each = var.onpremise_address_spaces
    content {
      name           = "to-onpremise-${replace(route.value, "/", "-")}"
      address_prefix = route.value
      next_hop_type  = "VirtualNetworkGateway"
    }
  }

  tags = local.common_tags
}

# Associate route table with all subnets
resource "azurerm_subnet_route_table_association" "frontend_hybrid" {
  subnet_id      = azurerm_subnet.frontend.id
  route_table_id = azurerm_route_table.hybrid.id
}

resource "azurerm_subnet_route_table_association" "backend_hybrid" {
  subnet_id      = azurerm_subnet.backend.id
  route_table_id = azurerm_route_table.hybrid.id
}

resource "azurerm_subnet_route_table_association" "database_hybrid" {
  subnet_id      = azurerm_subnet.database.id
  route_table_id = azurerm_route_table.hybrid.id
}