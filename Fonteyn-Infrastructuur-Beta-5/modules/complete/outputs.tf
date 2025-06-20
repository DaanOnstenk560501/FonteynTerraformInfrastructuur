# outputs.tf - Output Values

output "load_balancer_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.main.ip_address
}

output "web_server_ips" {
  description = "Private IP addresses of web servers"
  value       = [for nic in azurerm_network_interface.web : nic.ip_configuration[0].private_ip_address]
}

output "app_server_ips" {
  description = "Private IP addresses of app servers"
  value       = [for nic in azurerm_network_interface.app : nic.ip_configuration[0].private_ip_address]
}

output "database_ip" {
  description = "Private IP address of database server"
  value       = azurerm_network_interface.database.ip_configuration[0].private_ip_address
}

output "ssh_private_key" {
  description = "SSH private key for VM access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "connection_info" {
  description = "Information on how to connect to the infrastructure"
  value = {
    web_url = "http://${azurerm_public_ip.main.ip_address}"
    
    ssh_commands = {
      web_server_1 = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}"
      app_server_1 = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.app[0].ip_configuration[0].private_ip_address}"
      database     = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.database.ip_configuration[0].private_ip_address}"
    }
    
    setup_instructions = [
      "1. Save SSH key: terraform output -raw ssh_private_key > ssh_key.pem",
      "2. Set permissions: chmod 600 ssh_key.pem",
      "3. Access web interface: http://${azurerm_public_ip.main.ip_address}",
      "4. SSH to web server: ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}"
    ]
  }
}

output "resource_groups" {
  description = "Created resource groups"
  value = {
    main = azurerm_resource_group.main.name
  }
}

output "network_info" {
  description = "Network configuration details"
  value = {
    vnet_name     = azurerm_virtual_network.main.name
    vnet_cidr     = azurerm_virtual_network.main.address_space[0]
    frontend_cidr = azurerm_subnet.frontend.address_prefixes[0]
    backend_cidr  = azurerm_subnet.backend.address_prefixes[0]
    database_cidr = azurerm_subnet.database.address_prefixes[0]
  }
}

output "cost_estimate" {
  description = "Estimated monthly costs (approximate)"
  value = {
    note = "Estimated costs for ${var.web_vm_count + var.app_vm_count + 1} VMs of size ${var.vm_size}"
    vm_costs = "~€${(var.web_vm_count + var.app_vm_count + 1) * 30}/month for VMs"
    storage_costs = "~€10/month for storage"
    network_costs = "~€15/month for load balancer and public IP"
    total_estimate = "~€${(var.web_vm_count + var.app_vm_count + 1) * 30 + 25}/month"
    
    cost_optimization = [
      "Use auto-shutdown to reduce costs during non-business hours",
      "Consider B-series burstable VMs for variable workloads",
      "Stop VMs when not needed for testing",
      "Use Azure Cost Management for accurate tracking"
    ]
  }
}

output "testing_notes" {
  description = "Important notes for testing"
  value = {
    warning = "This is a TESTING configuration with relaxed security!"
    
    security_notes = [
      "SSH is allowed from any IP (0.0.0.0/0) - not for production!",
      "Database has default passwords - change before real use",
      "No SSL/TLS encryption configured",
      "VMs auto-shutdown at ${var.auto_shutdown_time} to save costs"
    ]
    
    next_steps = [
      "Test load balancer by accessing the public IP",
      "SSH into VMs to configure applications",
      "Set up proper SSL certificates for production",
      "Configure monitoring and alerts",
      "Implement proper backup strategy"
    ]
    
    cleanup = "Run 'terraform destroy' to remove all resources when done testing"
  }
}