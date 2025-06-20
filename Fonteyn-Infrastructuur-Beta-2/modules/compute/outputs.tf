output "compute_resource_group_name" {
  value = azurerm_resource_group.compute.name
}

output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_public_ip.ip_address
}

output "web_vm_ids" {
  value = azurerm_linux_virtual_machine.web[*].id
}

output "app_vm_ids" {
  value = azurerm_linux_virtual_machine.app[*].id
}

output "db_vm_id" {
  value = azurerm_linux_virtual_machine.db.id
}

output "web_vm_private_ips" {
  value = azurerm_network_interface.web[*].private_ip_address
}

output "app_vm_private_ips" {
  value = azurerm_network_interface.app[*].private_ip_address
}

output "db_vm_private_ip" {
  value = azurerm_network_interface.db.private_ip_address
}