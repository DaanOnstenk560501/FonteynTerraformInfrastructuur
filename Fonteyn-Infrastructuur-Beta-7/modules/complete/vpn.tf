# vpn.tf

# --- Public IP for VPN Gateway ---
resource "azurerm_public_ip" "vpn_gateway_pip" {
  name                = "pip-vpngw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static" # CORRECT: Static for Standard SKU
  sku                 = "Standard" # CORRECT: Standard SKU
  tags                = local.common_tags
}

# --- Azure VPN Gateway ---
resource "azurerm_virtual_network_gateway" "main" {
  name                = "vpngw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip.id
    private_ip_address_allocation = "Dynamic" # CORRECT: Dynamic for the internal IP config
    subnet_id                     = azurerm_subnet.gateway.id
  }
  tags = local.common_tags
}

# --- On-Premise Local Network Gateway ---
resource "azurerm_local_network_gateway" "onpremise" {
  name                = "lng-onpremise-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = "145.220.74.133" # Your on-premise public IP
  address_space       = ["192.168.2.0/24"] # Your on-premise network range

  tags                = local.common_tags
}

# --- VPN Connection (Site-to-Site) ---
resource "azurerm_virtual_network_gateway_connection" "s2s_connection" {
  name                           = "conn-s2s-${var.project_name}-${var.environment}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.main.name
  type                           = "IPsec"
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id       = azurerm_local_network_gateway.onpremise.id
  shared_key                     = "F0nTeyNPriVaTeKey1!"

  ipsec_policy {
    ike_encryption    = "GCMAES256"   # <--- CHANGE THIS: Use GCMAES256 to match pfSense AES256-GCM
    ike_integrity     = "SHA256"      # Phase 1 Hashing
    ipsec_encryption  = "AES256"      # Phase 2 Encryption
    ipsec_integrity   = "SHA256"      # Phase 2 Hashing
    dh_group          = "DHGroup14"   # DH Group for IKE/Phase 1
    pfs_group         = "PFS24"       # PFS Group for Phase 2
  }

  tags = local.common_tags
}

# --- Output for Azure VPN Gateway Public IP ---
output "azure_vpn_gateway_public_ip" {
  description = "The Public IP Address of the Azure VPN Gateway."
  value       = azurerm_public_ip.vpn_gateway_pip.ip_address
}