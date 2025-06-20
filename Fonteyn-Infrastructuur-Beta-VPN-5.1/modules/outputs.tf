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
    vpn_gateway_costs = "~€25/month for VPN Gateway (${var.vpn_gateway_sku})"
    total_estimate = "~€${(var.web_vm_count + var.app_vm_count + 1) * 30 + 50}/month"
    
    cost_optimization = [
      "Use auto-shutdown to reduce costs during non-business hours",
      "Consider B-series burstable VMs for variable workloads",
      "Stop VMs when not needed for testing",
      "Use Azure Cost Management for accurate tracking"
    ]
  }
}

output "hybrid_connectivity" {
  description = "Hybrid cloud connectivity information"
  value = {
    vpn_gateway = {
      public_ip = azurerm_public_ip.vpn_gateway.ip_address
      sku       = var.vpn_gateway_sku
      status    = "Gateway takes 30-45 minutes to provision"
    }
    
    on_premises_networks = {
      hoofdkantoor = {
        networks = var.hoofdkantoor_networks
        public_ip = var.hoofdkantoor_public_ip
        connection_name = "cn-hoofdkantoor-${var.environment}"
      }
      vakantiepark_nl = var.enable_vakantiepark_nl ? {
        networks = var.vakantiepark_nl_networks
        public_ip = var.vakantiepark_nl_public_ip
        connection_name = "cn-vakantiepark-nl-${var.environment}"
      } : null
    }
    
    azure_networks = {
      vnet_cidr = azurerm_virtual_network.main.address_space[0]
      subnets = {
        frontend = azurerm_subnet.frontend.address_prefixes[0]
        backend = azurerm_subnet.backend.address_prefixes[0]
        database = azurerm_subnet.database.address_prefixes[0]
        management = azurerm_subnet.management.address_prefixes[0]
        gateway = azurerm_subnet.gateway.address_prefixes[0]
      }
    }
    
    dns_configuration = {
      private_zone = azurerm_private_dns_zone.fonteyn_corp.name
      domain_controllers = var.onprem_dns_servers
    }
  }
}

output "azure_arc_info" {
  description = "Azure Arc configuration for hybrid management"
  sensitive   = true  # Added because workspace_key is sensitive
  value = var.enable_azure_arc ? {
    resource_group = azurerm_resource_group.azure_arc[0].name
    workspace_id = azurerm_log_analytics_workspace.azure_arc[0].workspace_id
    workspace_key = azurerm_log_analytics_workspace.azure_arc[0].primary_shared_key
    service_principal_id = azurerm_user_assigned_identity.azure_arc[0].client_id
    
    installation_command = "# Download and run Azure Arc installation script from Azure portal"
    servers_to_connect = [
      "FONTDC01 (192.168.2.100)",
      "FONTDC02 (192.168.2.99)",
      "File server",
      "Print server"
    ]
  } : null
}

output "pfsense_configuration" {
  description = "pfSense VPN configuration for on-premises firewall"
  value = {
    azure_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
    local_networks = var.hoofdkantoor_networks
    remote_networks = [azurerm_virtual_network.main.address_space[0]]
    shared_key = "*** Use the shared key from terraform.tfvars ***"
    
    ipsec_settings = {
      protocol = "IKEv2"
      encryption = "AES-256"
      hash = "SHA-256"
      dh_group = "14"
      lifetime = "28800"
      pfs_group = "14"
    }
    
    setup_steps = [
      "1. Go to VPN > IPsec in pfSense",
      "2. Add new Phase 1 entry with Azure gateway IP: ${azurerm_public_ip.vpn_gateway.ip_address}",
      "3. Set encryption to AES-256, hash to SHA-256, DH Group 14",
      "4. Add Phase 2 with local network ${var.hoofdkantoor_networks[0]} to remote ${azurerm_virtual_network.main.address_space[0]}",
      "5. Apply changes and check status in VPN > IPsec > Status"
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