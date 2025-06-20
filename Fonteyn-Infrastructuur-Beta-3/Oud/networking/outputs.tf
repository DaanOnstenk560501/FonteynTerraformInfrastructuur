# ==============================================================================
# NETWORKING MODULE OUTPUTS (FIXED FOR MODULE COMPATIBILITY)
# ==============================================================================

# Resource Group outputs
output "network_resource_group_name" {
  description = "Naam van de network resource group"
  value       = azurerm_resource_group.network.name
}

output "network_resource_group_location" {
  description = "Locatie van de network resource group"
  value       = azurerm_resource_group.network.location
}

# ==============================================================================
# HUB NETWORK OUTPUTS
# ==============================================================================

output "hub_vnet_id" {
  description = "Hub Virtual Network ID"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Hub Virtual Network naam"
  value       = azurerm_virtual_network.hub.name
}

output "hub_vnet_address_space" {
  description = "Hub Virtual Network address space"
  value       = azurerm_virtual_network.hub.address_space
}

output "hub_management_subnet_id" {
  description = "Hub management subnet ID"
  value       = azurerm_subnet.hub_management.id
}

# ==============================================================================
# WORKLOAD SPOKE OUTPUTS (FIXED FOR COMPUTE MODULE)
# ==============================================================================

output "workload_vnet_id" {
  description = "Workload Virtual Network ID"
  value       = azurerm_virtual_network.workload_spoke.id
}

output "workload_vnet_name" {
  description = "Workload Virtual Network naam"
  value       = azurerm_virtual_network.workload_spoke.name
}

# CRITICAL: These are the subnet IDs that the compute module expects
output "frontend_subnet_id" {
  description = "Frontend subnet ID voor compute module"
  value       = azurerm_subnet.frontend.id
}

output "backend_subnet_id" {
  description = "Backend subnet ID voor compute module"
  value       = azurerm_subnet.backend.id
}

output "database_subnet_id" {
  description = "Database subnet ID voor compute module"
  value       = azurerm_subnet.database.id
}

# ==============================================================================
# VPN GATEWAY OUTPUTS (FIXED NAMES)
# ==============================================================================

output "vpn_gateway_id" {
  description = "VPN Gateway ID"
  value       = azurerm_virtual_network_gateway.vpn_gateway.id
}

output "vpn_gateway_name" {
  description = "VPN Gateway naam"
  value       = azurerm_virtual_network_gateway.vpn_gateway.name
}

output "vpn_gateway_public_ip" {
  description = "VPN Gateway public IP voor NetLab configuratie"
  value       = azurerm_public_ip.vpn_gateway_ip.ip_address
}

# ==============================================================================
# CONDITIONAL OUTPUTS (Firewall & Bastion)
# ==============================================================================

# Azure Firewall outputs (conditional)
output "azure_firewall_id" {
  description = "Azure Firewall ID (null if disabled)"
  value       = var.enable_azure_firewall ? azurerm_firewall.main[0].id : null
}

output "azure_firewall_name" {
  description = "Azure Firewall naam (null if disabled)"
  value       = var.enable_azure_firewall ? azurerm_firewall.main[0].name : null
}

output "azure_firewall_private_ip" {
  description = "Azure Firewall private IP address (null if disabled)"
  value       = var.enable_azure_firewall ? azurerm_firewall.main[0].ip_configuration[0].private_ip_address : null
}

output "azure_firewall_public_ip" {
  description = "Azure Firewall public IP address (null if disabled)"
  value       = var.enable_azure_firewall ? azurerm_public_ip.firewall[0].ip_address : null
}

# Bastion outputs (conditional)
output "bastion_host_id" {
  description = "Azure Bastion Host ID (null if disabled)"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].id : null
}

output "bastion_host_fqdn" {
  description = "Azure Bastion Host FQDN (null if disabled)"
  value       = var.enable_bastion ? azurerm_bastion_host.main[0].dns_name : null
}

# ==============================================================================
# SECURITY GROUP OUTPUTS
# ==============================================================================

output "frontend_nsg_id" {
  description = "Frontend Network Security Group ID"
  value       = azurerm_network_security_group.frontend.id
}

output "backend_nsg_id" {
  description = "Backend Network Security Group ID"
  value       = azurerm_network_security_group.backend.id
}

output "database_nsg_id" {
  description = "Database Network Security Group ID"
  value       = azurerm_network_security_group.database.id
}

# ==============================================================================
# DNS OUTPUTS
# ==============================================================================

output "private_dns_zone_name" {
  description = "Private DNS zone naam"
  value       = azurerm_private_dns_zone.internal.name
}

output "private_dns_zone_id" {
  description = "Private DNS zone ID"
  value       = azurerm_private_dns_zone.internal.id
}

# ==============================================================================
# SIMPLIFIED CONNECTION INFO (FIXED)
# ==============================================================================

output "netlab_connection_info" {
  description = "Connectie informatie voor NetLab VPN setup"
  value = {
    azure_gateway_ip = azurerm_public_ip.vpn_gateway_ip.ip_address
    azure_networks   = [var.hub_vnet_address_space, var.workload_vnet_address_space]
    shared_key       = "Fonteyn2025NetLab!" # Static for NetLab
  }
  sensitive = false # Remove sensitive flag since it's mainly IP addresses
}

output "cost_optimization_summary" {
  description = "Overzicht van kostenbesparingen"
  value = {
    firewall_enabled = var.enable_azure_firewall
    bastion_enabled = var.enable_bastion
    firewall_savings = var.enable_azure_firewall ? "€0 (enabled)" : "€500/month saved"
    bastion_savings  = var.enable_bastion ? "€140/month cost" : "€140/month saved"
    total_monthly_cost = var.enable_azure_firewall && var.enable_bastion ? "€640/month" : 
                        var.enable_azure_firewall ? "€500/month" : 
                        var.enable_bastion ? "€140/month" : "€0/month"
  }
}