# outputs.tf - Output Values for Windows Infrastructure

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

output "admin_username" {
  description = "Administrator username for Windows VMs"
  value       = var.admin_username
}

output "admin_password" {
  description = "Administrator password for Windows VMs"
  value       = random_password.admin_password.result
  sensitive   = true
}

output "connection_info" {
  description = "Information on how to connect to the Windows infrastructure"
  value = {
    web_url = "http://${azurerm_public_ip.main.ip_address}"
    
    rdp_connections = {
      web_server_1 = "mstsc /v:${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}"
      app_server_1 = length(azurerm_network_interface.app) > 0 ? "mstsc /v:${azurerm_network_interface.app[0].ip_configuration[0].private_ip_address}" : "No app servers configured"
      database     = "mstsc /v:${azurerm_network_interface.database.ip_configuration[0].private_ip_address}"
    }
    
    setup_instructions = [
      "1. Get admin password: terraform output -raw admin_password",
      "2. Copy password to clipboard for RDP connections",
      "3. Access web interface: http://${azurerm_public_ip.main.ip_address}",
      "4. Connect to web server via RDP: mstsc /v:${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}",
      "5. Use username: ${var.admin_username} and the generated password",
      "6. Note: RDP is only allowed from specified IP ranges for security"
    ]
    
    security_notes = [
      "RDP (port 3389) is configured for remote access",
      "WinRM (ports 5985/5986) is enabled for PowerShell remoting", 
      "SQL Server is accessible on port 1433 from backend subnet only",
      "All VMs are Windows Server 2022 with automatic updates enabled"
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
  description = "Estimated monthly costs for Windows VMs (approximate)"
  value = {
    note = "Estimated costs for ${var.web_vm_count + var.app_vm_count + 1} Windows Server 2022 VMs of size ${var.vm_size}"
    vm_costs = "~€${(var.web_vm_count + var.app_vm_count + 1) * 45}/month for Windows VMs (30-50% higher than Linux)"
    storage_costs = "~€15/month for premium storage (Windows requires more space)"
    network_costs = "~€15/month for load balancer and public IP"
    licensing_savings = var.enable_azure_hybrid_benefit ? "Azure Hybrid Benefit enabled - potential 40% savings" : "Consider Azure Hybrid Benefit for Windows Server license savings"
    total_estimate = "~€${(var.web_vm_count + var.app_vm_count + 1) * 45 + 30}/month"
    
    cost_optimization = [
      "Enable Azure Hybrid Benefit if you have Windows Server licenses with Software Assurance",
      "Use Reserved Instances for 1-3 year commitments (20-60% savings)",
      "Consider B-series burstable VMs for variable workloads",
      "Use auto-shutdown schedules to reduce costs during non-business hours",
      "Monitor with Azure Cost Management for accurate tracking"
    ]
  }
}

output "windows_features" {
  description = "Windows Server 2022 features and capabilities"
  value = {
    os_version = "Windows Server 2022 Datacenter Azure Edition"
    
    installed_features = [
      "IIS 10.0 with ASP.NET support (web servers)",
      ".NET Framework 4.8 and .NET Core 6.0",
      "SQL Server Express (database server)",
      "Windows Defender with enhanced security",
      "PowerShell 5.1 and PowerShell Core"
    ]
    
    security_features = [
      "Secured-Core Server with TPM 2.0",
      "Virtualization-Based Security (VBS)",
      "Windows Defender System Guard",
      "TLS 1.3 enabled by default", 
      "Enhanced firewall with advanced security"
    ]
    
    management_capabilities = [
      "RDP for graphical remote access",
      "WinRM for PowerShell remoting",
      "Azure VM Agent for extensions",
      "Boot diagnostics for troubleshooting",
      "Automatic Windows Updates enabled"
    ]
  }
}

output "application_info" {
  description = "Application deployment information"
  value = {
    web_servers = {
      framework = ".NET Framework 4.8 & .NET Core 6.0"
      web_server = "IIS 10.0"
      default_page = "Custom Fonteyn welcome page deployed"
      access_url = "http://${azurerm_public_ip.main.ip_address}"
    }
    
    app_servers = {
      runtime = ".NET Core 6.0"
      application = "Simple HTTP listener on port 8080"
      framework = "Console application with HTTP server"
    }
    
    database_server = {
      engine = "SQL Server Express"
      port = "1433 (TCP)"
      instance = "SQLEXPRESS"
      test_database = "FonteynTest"
    }
  }
}

output "testing_notes" {
  description = "Important notes for testing Windows infrastructure"
  value = {
    warning = "This is a TESTING configuration with relaxed security for Windows VMs!"
    
    security_notes = [
      "RDP is allowed from specified IP ranges - verify var.allowed_ip_ranges",
      "Auto-generated admin password - store securely",
      "SQL Server has basic authentication - enhance for production",
      "Windows Firewall configured but additional hardening recommended",
      "VMs auto-shutdown at ${var.auto_shutdown_time} to save costs"
    ]
    
    connection_steps = [
      "1. Get admin password: terraform output -raw admin_password",
      "2. Use Remote Desktop Connection (mstsc) to connect to VMs",
      "3. Enter username: ${var.admin_username} and the generated password",
      "4. Web servers accessible via load balancer IP",
      "5. App servers accessible internally on port 8080",
      "6. Database accessible from backend subnet on port 1433"
    ]
    
    next_steps = [
      "Test load balancer by accessing the public IP",
      "RDP into VMs to verify applications are running",
      "Configure SSL certificates for production use",
      "Implement proper Active Directory integration",
      "Set up Windows monitoring and backup solutions",
      "Apply additional security hardening as needed"
    ]
    
    cleanup = "Run 'terraform destroy' to remove all resources when done testing"
  }
}