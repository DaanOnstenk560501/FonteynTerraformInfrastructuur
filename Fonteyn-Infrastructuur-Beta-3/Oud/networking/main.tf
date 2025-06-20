# ========================================
# NETWORKING MODULE (FIXED)
# ========================================

# modules/networking/main.tf
# Resource Group voor netwerk
resource "azurerm_resource_group" "network" {
  name     = "rg-${var.project_name}-network"
  location = var.location
  tags     = merge(var.tags, {
    Purpose = "Hub-Network-Infrastructure"
  })
}

# ==============================================================================
# HUB VIRTUAL NETWORK (Azure Central Hub)
# ==============================================================================

# Virtual Network (Hub - Azure centrale hub)
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.project_name}-hub"
  address_space       = [var.hub_vnet_address_space] # 10.0.0.0/16
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  
  tags = merge(var.tags, {
    NetworkType = "Hub"
    Purpose     = "CentralConnectivity"
  })
}

# Gateway Subnet (vereist voor VPN Gateway)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # Naam moet exact "GatewaySubnet" zijn
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix] # 10.0.0.0/27
}

# Azure Firewall Subnet (subnet blijft bestaan voor toekomstige activering)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # Naam moet exact "AzureFirewallSubnet" zijn
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix] # 10.0.1.0/26
}

# Azure Bastion Subnet (subnet blijft bestaan voor toekomstige activering)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # Naam moet exact "AzureBastionSubnet" zijn
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix] # 10.0.2.0/27
}

# Hub Management Subnet
resource "azurerm_subnet" "hub_management" {
  name                 = "snet-hub-management"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_management_subnet_prefix] # 10.0.3.0/24
}

# ==============================================================================
# AZURE WORKLOAD SPOKE NETWORK (FIXED FOR COMPUTE MODULE)
# ==============================================================================

# Spoke VNet voor Azure workloads
resource "azurerm_virtual_network" "workload_spoke" {
  name                = "vnet-${var.project_name}-workload"
  address_space       = [var.workload_vnet_address_space] # 10.1.0.0/16
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  
  tags = merge(var.tags, {
    NetworkType = "Spoke"
    Purpose     = "AzureWorkloads"
  })
}

# Frontend Subnet (webservers) - FIXED NAME
resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.workload_spoke.name
  address_prefixes     = [var.frontend_subnet_prefix] # 10.1.1.0/24
}

# Backend Subnet (app servers) - FIXED NAME
resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.workload_spoke.name
  address_prefixes     = [var.backend_subnet_prefix] # 10.1.2.0/24
}

# Database Subnet - FIXED NAME
resource "azurerm_subnet" "database" {
  name                 = "snet-database"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.workload_spoke.name
  address_prefixes     = [var.database_subnet_prefix] # 10.1.3.0/24
  
  # SQL delegation voor Azure SQL
  delegation {
    name = "sql-delegation"
    service_delegation {
      name = "Microsoft.Sql/managedInstances"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# ==============================================================================
# VPN GATEWAY & CONNECTIVITY (FIXED)
# ==============================================================================

# Public IP voor VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_ip" {
  name                = "pip-${var.project_name}-vpn-gateway"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"  # FIXED: Static voor Standard SKU
  sku                 = "Standard" # FIXED: Standard SKU
  zones               = ["1", "2", "3"] # Zone redundancy
  
  tags = var.tags
}

# VPN Gateway - FIXED NAAM
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "vgw-${var.project_name}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = var.enable_bgp
  sku                 = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
  
  tags = var.tags
}

# ==============================================================================
# NETWORK SECURITY GROUPS (IMPROVED FOR COMPUTE MODULE)
# ==============================================================================

# NSG voor Frontend (HTTP/HTTPS + load balancer health probes)
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-${var.project_name}-frontend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLoadBalancerProbe"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_management_ips
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# NSG voor Backend (alleen vanaf frontend)
resource "azurerm_network_security_group" "backend" {
  name                = "nsg-${var.project_name}-backend"
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
    source_address_prefixes    = var.allowed_management_ips
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLoadBalancerProbe"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# NSG voor Database (alleen vanaf backend) - FIXED PORT
resource "azurerm_network_security_group" "database" {
  name                = "nsg-${var.project_name}-database"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromBackend"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"  # FIXED: MySQL port instead of SQL Server
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
    source_address_prefixes    = var.allowed_management_ips
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Subnet-NSG Associations
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

# ==============================================================================
# CONDITIONAL AZURE FIREWALL
# ==============================================================================

# Public IP voor Azure Firewall (alleen als enabled)
resource "azurerm_public_ip" "firewall" {
  count = var.enable_azure_firewall ? 1 : 0
  
  name                = "pip-${var.project_name}-fw"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# Azure Firewall (alleen als enabled)
resource "azurerm_firewall" "main" {
  count = var.enable_azure_firewall ? 1 : 0
  
  name                = "afw-${var.project_name}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = var.tags
}

# ==============================================================================
# CONDITIONAL AZURE BASTION
# ==============================================================================

# Public IP voor Bastion (alleen als enabled)
resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0
  
  name                = "pip-${var.project_name}-bastion"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# Azure Bastion voor secure management (alleen als enabled)
resource "azurerm_bastion_host" "main" {
  count = var.enable_bastion ? 1 : 0
  
  name                = "bas-${var.project_name}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}

# ==============================================================================
# VNET PEERINGS (Hub-and-Spoke connections) - FIXED DEPENDENCIES
# ==============================================================================

# Hub to Workload Spoke Peering
resource "azurerm_virtual_network_peering" "hub_to_workload" {
  name                      = "peer-hub-to-workload"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.workload_spoke.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "workload_to_hub" {
  name                      = "peer-workload-to-hub"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.workload_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
  
  depends_on = [azurerm_virtual_network_gateway.vpn_gateway] # FIXED NAME
}

# ==============================================================================
# PRIVATE DNS ZONE
# ==============================================================================

# Private DNS Zone voor internal domain
resource "azurerm_private_dns_zone" "internal" {
  name                = "fonteyn.internal"
  resource_group_name = azurerm_resource_group.network.name
  
  tags = var.tags
}

# Link DNS zone naar Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = true
  
  tags = var.tags
}

# Link DNS zone naar Workload VNet
resource "azurerm_private_dns_zone_virtual_network_link" "workload" {
  name                  = "link-workload"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.workload_spoke.id
  registration_enabled  = true
  
  tags = var.tags
}