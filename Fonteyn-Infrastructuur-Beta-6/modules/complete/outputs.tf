# outputs.tf - Comprehensive Outputs for Fonteyn Hybrid Infrastructure

# VPN Gateway Configuration Information
output "azure_vpn_gateway_info" {
  description = "Azure VPN Gateway information for configuring Fonteyn on-premises firewall"
  value = {
    public_ip_address = azurerm_public_ip.vpn_gateway.ip_address
    bgp_peering_ip    = azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses[0]
    azure_bgp_asn     = azurerm_virtual_network_gateway.vpn.bgp_settings[0].asn
    gateway_sku       = var.vpn_gateway_sku
    connection_type   = "IPsec"
  }
}

output "vpn_connection_status" {
  description = "VPN connection details for monitoring"
  sensitive   = true
  value = {
    connection_name         = azurerm_virtual_network_gateway_connection.fonteyn_connection.name
    connection_type         = azurerm_virtual_network_gateway_connection.fonteyn_connection.type
    shared_key_configured   = var.vpn_shared_key != "" ? "Yes" : "No"
    bgp_enabled            = azurerm_virtual_network_gateway_connection.fonteyn_connection.enable_bgp
    local_gateway_address  = var.onpremise_gateway_ip
  }
}

# Network Configuration Information
output "azure_network_info" {
  description = "Azure network configuration for routing setup"
  value = {
    vnet_name         = azurerm_virtual_network.main.name
    vnet_address_space = azurerm_virtual_network.main.address_space
    dns_servers       = azurerm_virtual_network.main.dns_servers
    subnet_ranges = {
      frontend = azurerm_subnet.frontend.address_prefixes[0]
      backend  = azurerm_subnet.backend.address_prefixes[0]
      database = azurerm_subnet.database.address_prefixes[0]
      gateway  = azurerm_subnet.gateway.address_prefixes[0]
    }
  }
}

output "fonteyn_onpremise_config" {
  description = "On-premises network configuration summary"
  value = {
    gateway_ip       = var.onpremise_gateway_ip
    address_spaces   = var.onpremise_address_spaces
    dns_servers      = var.onpremise_dns_servers
    bgp_asn         = var.onpremise_bgp_asn
    bgp_peer_ip     = var.onpremise_bgp_peer_ip
    domain_info = {
      domain_name   = var.active_directory_domain
      netbios_name  = var.active_directory_netbios
      dc1_ip        = "192.168.2.100"
      dc2_ip        = "192.168.2.99"
    }
  }
}

# Virtual Machine Information
output "virtual_machines" {
  description = "Information about all deployed VMs"
  value = {
    web_servers = [
      for i in range(var.web_vm_count) : {
        name       = azurerm_windows_virtual_machine.web[i].name
        private_ip = azurerm_network_interface.web[i].ip_configuration[0].private_ip_address
        subnet     = "frontend"
        role       = "webserver"
      }
    ]
    app_servers = [
      for i in range(var.app_vm_count) : {
        name       = azurerm_windows_virtual_machine.app[i].name
        private_ip = azurerm_network_interface.app[i].ip_configuration[0].private_ip_address
        subnet     = "backend"
        role       = "appserver"
      }
    ]
    database_server = {
      name       = azurerm_windows_virtual_machine.database.name
      private_ip = azurerm_network_interface.database.ip_configuration[0].private_ip_address
      subnet     = "database"
      role       = "database"
    }
  }
}

output "load_balancer_info" {
  description = "Load balancer configuration and access information"
  value = {
    public_ip_address = azurerm_public_ip.main.ip_address
    fqdn             = azurerm_public_ip.main.fqdn
    backend_pool_vms = [
      for i in range(var.web_vm_count) : {
        vm_name    = azurerm_windows_virtual_machine.web[i].name
        private_ip = azurerm_network_interface.web[i].ip_configuration[0].private_ip_address
      }
    ]
    health_probe = {
      protocol = "Http"
      port     = 80
      path     = "/"
    }
  }
}

# Security and Access Information
output "security_info" {
  description = "Security configuration and access details"
  value = {
    admin_username = var.admin_username
    key_vault = {
      name     = azurerm_key_vault.main.name
      uri      = azurerm_key_vault.main.vault_uri
      secrets  = ["vm-admin-password", "vpn-shared-key"]
    }
    allowed_ip_ranges = var.allowed_ip_ranges
    domain_join = {
      enabled     = var.domain_join.enabled
      domain_name = var.domain_join.domain_name
      ou_path     = var.domain_join.ou_path
    }
    antimalware_enabled = var.enable_antimalware
  }
}

# Domain Join Information
output "domain_configuration" {
  description = "Active Directory domain configuration details"
  value = {
    domain_name      = var.active_directory_domain
    netbios_name     = var.active_directory_netbios
    ou_path          = var.domain_join.ou_path
    dns_servers      = var.onpremise_dns_servers
    domain_join_user = "${var.active_directory_netbios}\\${var.admin_username}"
    required_ou_creation = "Please ensure OU '${var.domain_join.ou_path}' exists in your on-premises AD"
  }
}

# Monitoring and Management
output "monitoring_info" {
  description = "Monitoring and management resource details"
  sensitive   = true
  value = {
    log_analytics_workspace = {
      name         = azurerm_log_analytics_workspace.main.name
      workspace_id = azurerm_log_analytics_workspace.main.workspace_id
    }
    storage_account = {
      name                = azurerm_storage_account.diagnostics.name
      primary_endpoint    = azurerm_storage_account.diagnostics.primary_blob_endpoint
    }
    application_insights = {
      name               = azurerm_application_insights.main.name
      instrumentation_key = azurerm_application_insights.main.instrumentation_key
      app_id            = azurerm_application_insights.main.app_id
    }
    automation_account = {
      name = azurerm_automation_account.main.name
    }
  }
}

# Resource Group Information
output "resource_group_info" {
  description = "Resource group information"
  value = {
    name     = azurerm_resource_group.main.name
    location = azurerm_resource_group.main.location
    tags     = azurerm_resource_group.main.tags
  }
}

# Cost Management Information
output "cost_management" {
  description = "Cost optimization settings"
  value = {
    auto_shutdown_enabled = var.auto_shutdown_time != ""
    auto_shutdown_time    = var.auto_shutdown_time
    backup_enabled        = var.enable_backup
    vm_sizes = {
      web_vms      = var.vm_size
      app_vms      = var.vm_size
      database_vm  = var.vm_size
    }
    storage_type = var.storage_account_type
    azure_hybrid_benefit = var.enable_azure_hybrid_benefit
  }
}

# Connection Testing Commands
output "connectivity_testing" {
  description = "Commands to test connectivity after deployment"
  value = {
    test_web_access = "curl http://${azurerm_public_ip.main.ip_address}"
    test_vm_connectivity = [
      for i in range(var.web_vm_count) : 
      "Test-NetConnection -ComputerName ${azurerm_network_interface.web[i].ip_configuration[0].private_ip_address} -Port 3389"
    ]
    test_domain_connectivity = [
      "Test-NetConnection -ComputerName 192.168.2.100 -Port 389",
      "nslookup fonteyn.corp 192.168.2.100",
      "ping 192.168.2.100"
    ]
  }
}

# On-Premises Configuration Checklist
output "onpremise_configuration_checklist" {
  description = "Step-by-step checklist for configuring Fonteyn on-premises infrastructure"
  sensitive   = true
  value = {
    vpn_device_configuration = [
      "Configure peer IP: ${azurerm_public_ip.vpn_gateway.ip_address}",
      "Set shared key: ${substr(var.vpn_shared_key, 0, 10)}... (full key in Key Vault)",
      "Configure BGP ASN: 65515 (Azure side)",
      "Set BGP peer IP: ${azurerm_virtual_network_gateway.vpn.bgp_settings[0].peering_addresses[0].default_addresses[0]}",
      "Enable IPsec tunnel for networks: ${join(", ", azurerm_virtual_network.main.address_space)}"
    ]
    firewall_rules = [
      "Allow UDP 500 and 4500 from/to ${azurerm_public_ip.vpn_gateway.ip_address}",
      "Allow TCP 389, 636, 3268, 3269 from 10.0.0.0/16 to DCs",
      "Allow UDP 88, 123 from 10.0.0.0/16 to DCs",
      "Allow TCP 53 and UDP 53 from 10.0.0.0/16 to DCs",
      "Allow ICMP from 10.0.0.0/16 for testing"
    ]
    dns_configuration = [
      "Ensure DC1 (192.168.2.100) is accessible from Azure VMs",
      "Consider conditional forwarders for Azure DNS (168.63.129.16)",
      "Test DNS resolution: nslookup fonteyn.corp from Azure VMs"
    ]
    active_directory_tasks = [
      "Create OU: ${var.domain_join.ou_path}",
      "Grant domain join permissions to ${var.active_directory_netbios}\\${var.admin_username}",
      "Configure AD Sites and Services for Azure subnet",
      "Monitor domain joins in Event Viewer on DCs"
    ]
    routing_configuration = [
      "Add static routes for 10.0.0.0/16 via VPN tunnel",
      "Configure BGP advertisement if using dynamic routing",
      "Test connectivity: ping from on-premises to Azure VMs"
    ]
  }
}

# Quick Start URLs
output "quick_start_urls" {
  description = "Quick access URLs and commands"
  value = {
    web_application    = "http://${azurerm_public_ip.main.ip_address}"
    azure_portal_rg    = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/overview"
    key_vault_url      = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_key_vault.main.id}/overview"
    vpn_gateway_url    = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_virtual_network_gateway.vpn.id}/overview"
  }
}

# Summary Information
output "deployment_summary" {
  description = "High-level summary of the deployment"
  value = {
    infrastructure_type = "Hybrid Cloud (Azure + On-Premises AD)"
    total_vms = var.web_vm_count + var.app_vm_count + 1
    vm_breakdown = {
      web_servers = var.web_vm_count
      app_servers = var.app_vm_count
      database_servers = 1
    }
    network_connectivity = "Site-to-Site VPN with BGP"
    domain_controller_location = "On-Premises (Fonteyn)"
    estimated_monthly_cost = "Estimate: €300-500/month (depending on usage)"
    next_steps = [
      "1. Configure on-premises VPN device with provided settings",
      "2. Create required AD OU: ${var.domain_join.ou_path}",
      "3. Test VPN connectivity and domain join",
      "4. Access web application at: http://${azurerm_public_ip.main.ip_address}"
    ]
  }
}