# Dit zijn de "resultaten" die andere modules kunnen gebruiken

output "vnet_name" {
  description = "Naam van het Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "frontend_subnet_id" {
  description = "ID van het frontend subnet"
  value       = azurerm_subnet.frontend.id
}

output "backend_subnet_id" {
  description = "ID van het backend subnet"
  value       = azurerm_subnet.backend.id
}

output "database_subnet_id" {
  description = "ID van het database subnet"
  value       = azurerm_subnet.database.id
}

output "resource_group_name" {
  description = "Naam van de network resource group"
  value       = azurerm_resource_group.network.name
}