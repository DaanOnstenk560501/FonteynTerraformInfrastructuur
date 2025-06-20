# outputs.tf

output "admin_password" {
  description = "The randomly generated admin password for VMs. Store securely!"
  value       = random_password.admin_password.result
  sensitive   = true # Mark as sensitive to prevent plain-text output in logs
}

output "key_vault_uri" {
  description = "The URI of the Azure Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "server_private_ips" {
  description = "Private IP addresses of the deployed servers."
  value = merge(
    { for k, nic in azurerm_network_interface.servers_nic : k => nic.private_ip_address },
    { "workstation" = azurerm_network_interface.workstation_nic.private_ip_address }
  )
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.main.name
}

output "virtual_network_name" {
  description = "The name of the virtual network."
  value       = azurerm_virtual_network.main.name
}