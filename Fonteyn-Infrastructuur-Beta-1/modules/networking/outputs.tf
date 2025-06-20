output "network_resource_group_name" {
  value = azurerm_resource_group.network.name
}

output "network_resource_group_location" {
  value = azurerm_resource_group.network.location
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "frontend_subnet_id" {
  value = azurerm_subnet.frontend.id
}

output "backend_subnet_id" {
  value = azurerm_subnet.backend.id
}

output "database_subnet_id" {
  value = azurerm_subnet.database.id
}

output "management_subnet_id" {
  value = azurerm_subnet.management.id
}

output "frontend_nsg_id" {
  value = azurerm_network_security_group.frontend.id
}

output "backend_nsg_id" {
  value = azurerm_network_security_group.backend.id
}

output "database_nsg_id" {
  value = azurerm_network_security_group.database.id
}