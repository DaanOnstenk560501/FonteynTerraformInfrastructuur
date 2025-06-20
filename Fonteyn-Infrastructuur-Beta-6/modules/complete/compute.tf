# compute.tf - Windows VMs configured for Fonteyn hybrid domain join

# PowerShell setup scripts for different tiers
locals {
  web_setup_script = <<-SCRIPT
    # Install IIS with ASP.NET support
    Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console -IncludeManagementTools
    
    # Install .NET Core Hosting Bundle
    try {
        $hostingBundleUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C8-47E9B77CE0F0/dotnet-hosting-6.0.0-win.exe'
        $localPath = 'C:\\temp\\dotnet-hosting-bundle.exe'
        New-Item -ItemType Directory -Path 'C:\\temp' -Force
        Invoke-WebRequest -Uri $hostingBundleUrl -OutFile $localPath -UseBasicParsing
        Start-Process -FilePath $localPath -ArgumentList '/quiet' -Wait
        Write-Host "✅ .NET Core Hosting Bundle installed successfully"
    } catch {
        Write-Host "⚠️ .NET Core Hosting Bundle installation failed: $_"
    }
    
    # Configure Windows Firewall for web server
    New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
    New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
    
    # Create Fonteyn welcome page
    $welcomePage = @"
<!DOCTYPE html>
<html>
<head>
    <title>Fonteyn Azure Web Server - $env:COMPUTERNAME</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 1000px; margin: 50px auto; background: rgba(255,255,255,0.1); padding: 40px; border-radius: 15px; backdrop-filter: blur(10px); }
        h1 { color: #fff; text-align: center; margin-bottom: 30px; font-size: 2.5em; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 30px 0; }
        .info-card { background: rgba(255,255,255,0.2); padding: 20px; border-radius: 10px; }
        .info-card h3 { margin-top: 0; color: #ffd700; }
        .status { text-align: center; margin: 30px 0; }
        .status-badge { display: inline-block; padding: 10px 20px; background: #28a745; border-radius: 25px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌟 Fonteyn Web Server</h1>
        <div class="status">
            <span class="status-badge">✅ Online & Ready</span>
        </div>
        <div class="info-grid">
            <div class="info-card">
                <h3>🖥️ Server Information</h3>
                <p><strong>Hostname:</strong> $env:COMPUTERNAME</p>
                <p><strong>Domain:</strong> $env:USERDOMAIN</p>
                <p><strong>OS:</strong> Windows Server 2022</p>
                <p><strong>IP Address:</strong> $((Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet*)[0].IPAddress)</p>
            </div>
            <div class="info-card">
                <h3>🚀 Technology Stack</h3>
                <p><strong>Web Server:</strong> IIS 10.0</p>
                <p><strong>Framework:</strong> .NET 6.0 & .NET Framework 4.8</p>
                <p><strong>Load Balancer:</strong> Azure Standard LB</p>
                <p><strong>Architecture:</strong> Hybrid Cloud</p>
            </div>
            <div class="info-card">
                <h3>🏢 Environment</h3>
                <p><strong>Company:</strong> Fonteyn</p>
                <p><strong>Environment:</strong> ${var.environment}</p>
                <p><strong>Location:</strong> ${var.location}</p>
                <p><strong>Timestamp:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            </div>
        </div>
        <div style="text-align: center; margin-top: 40px; font-size: 0.9em; opacity: 0.8;">
            This server is part of the Fonteyn hybrid infrastructure, connected to on-premises Active Directory
        </div>
    </div>
</body>
</html>
"@
    
    $welcomePage | Out-File -FilePath 'C:\\inetpub\\wwwroot\\index.html' -Encoding UTF8
    
    # Start and configure services
    Start-Service W3SVC
    Set-Service W3SVC -StartupType Automatic
    iisreset
    
    Write-Host "✅ Fonteyn Web Server setup completed successfully"
  SCRIPT

  app_setup_script = <<-SCRIPT
    # Install .NET Core Runtime and SDK
    try {
        $runtimeUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C8-47E9B77CE0F0/dotnet-runtime-6.0.0-win-x64.exe'
        $localPath = 'C:\\temp\\dotnet-runtime.exe'
        New-Item -ItemType Directory -Path 'C:\\temp' -Force
        Invoke-WebRequest -Uri $runtimeUrl -OutFile $localPath -UseBasicParsing
        Start-Process -FilePath $localPath -ArgumentList '/quiet' -Wait
        Write-Host "✅ .NET Runtime installed successfully"
    } catch {
        Write-Host "⚠️ .NET Runtime installation failed: $_"
    }
    
    # Create application directories
    New-Item -ItemType Directory -Path 'C:\\Apps\\FonteynApp' -Force
    New-Item -ItemType Directory -Path 'C:\\Apps\\Logs' -Force
    
    # Configure Windows Firewall for app server
    New-NetFirewallRule -DisplayName "Allow App Port 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
    
    # Create Fonteyn application service placeholder
    $appCode = @'
using System;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.IO;

class FonteynAppServer
{
    static async Task Main(string[] args)
    {
        var listener = new HttpListener();
        listener.Prefixes.Add("http://+:8080/");
        
        try 
        {
            listener.Start();
            Console.WriteLine($"🚀 Fonteyn App Server started on {Environment.MachineName}:8080");
            Console.WriteLine($"📅 Started at: {DateTime.Now}");
            Console.WriteLine($"🏢 Domain: {Environment.UserDomainName}");
            Console.WriteLine("Press Ctrl+C to stop the server");
            
            while (true)
            {
                var context = await listener.GetContextAsync();
                var response = context.Response;
                
                var html = $@"
                <html>
                <head>
                    <title>Fonteyn Application Server</title>
                    <style>
                        body {{ font-family: 'Segoe UI', Arial; background: #f8f9fa; margin: 40px; }}
                        .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
                        h1 {{ color: #007bff; text-align: center; }}
                        .info {{ background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 15px 0; }}
                        .badge {{ display: inline-block; padding: 5px 10px; background: #28a745; color: white; border-radius: 3px; font-size: 0.8em; }}
                    </style>
                </head>
                <body>
                    <div class=""container"">
                        <h1>🏢 Fonteyn Application Server</h1>
                        <span class=""badge"">✅ Active</span>
                        <div class=""info"">
                            <p><strong>Server:</strong> {Environment.MachineName}</p>
                            <p><strong>Domain:</strong> {Environment.UserDomainName}</p>
                            <p><strong>Platform:</strong> {Environment.OSVersion}</p>
                            <p><strong>Runtime:</strong> .NET 6.0</p>
                            <p><strong>Role:</strong> Backend Application Server</p>
                            <p><strong>Request Time:</strong> {DateTime.Now}</p>
                            <p><strong>Architecture:</strong> Hybrid Cloud (Azure + On-Premises AD)</p>
                        </div>
                        <p style=""text-align: center; color: #666; margin-top: 30px;"">
                            This application server is part of the Fonteyn infrastructure tier
                        </p>
                    </div>
                </body>
                </html>";
                
                var buffer = Encoding.UTF8.GetBytes(html);
                response.ContentLength64 = buffer.Length;
                response.ContentType = "text/html";
                response.OutputStream.Write(buffer, 0, buffer.Length);
                response.OutputStream.Close();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Error: {ex.Message}");
        }
        finally
        {
            listener?.Stop();
        }
    }
}
'@
    
    $appCode | Out-File -FilePath 'C:\\Apps\\FonteynApp\\Program.cs' -Encoding UTF8
    
    Write-Host "✅ Fonteyn Application Server setup completed successfully"
    Write-Host "ℹ️ Application code saved to C:\\Apps\\FonteynApp\\Program.cs"
  SCRIPT

  database_setup_script = <<-SCRIPT
    # Download and install SQL Server Express
    try {
        $sqlExpressUrl = 'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe'
        $localPath = 'C:\\temp\\SQLServerExpress.exe'
        New-Item -ItemType Directory -Path 'C:\\temp' -Force
        
        Write-Host "📥 Downloading SQL Server Express..."
        Invoke-WebRequest -Uri $sqlExpressUrl -OutFile $localPath -UseBasicParsing
        
        Write-Host "🔧 Installing SQL Server Express..."
        $installArgs = @(
            '/ACTION=Install',
            '/FEATURES=SQLEngine',
            '/INSTANCENAME=SQLEXPRESS',
            '/SQLSVCACCOUNT="NT AUTHORITY\\NETWORK SERVICE"',
            '/SQLSYSADMINACCOUNTS="BUILTIN\\Administrators"',
            '/TCPENABLED=1',
            '/IACCEPTSQLSERVERLICENSETERMS',
            '/QUIET'
        )
        Start-Process -FilePath $localPath -ArgumentList $installArgs -Wait -NoNewWindow
        
        # Wait for installation to complete
        Start-Sleep -Seconds 30
        
        # Enable and start SQL Server services
        Write-Host "🚀 Configuring SQL Server services..."
        Set-Service -Name 'MSSQL$SQLEXPRESS' -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
        
        Set-Service -Name 'SQLBrowser' -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name 'SQLBrowser' -ErrorAction SilentlyContinue
        
        Write-Host "✅ SQL Server Express installation completed"
    } catch {
        Write-Host "⚠️ SQL Server Express installation encountered an issue: $_"
        Write-Host "ℹ️ Manual installation may be required"
    }
    
    # Configure Windows Firewall for SQL Server
    New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
    New-NetFirewallRule -DisplayName "Allow SQL Browser" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow
    
    # Create database setup script
    $sqlSetupScript = @"
-- Fonteyn Database Setup Script
USE master;
GO

-- Create Fonteyn test database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'FonteynTest')
BEGIN
    CREATE DATABASE FonteynTest;
END
GO

USE FonteynTest;
GO

-- Create test table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ServerInfo' AND xtype='U')
BEGIN
    CREATE TABLE ServerInfo (
        ID int IDENTITY(1,1) PRIMARY KEY,
        ServerName NVARCHAR(50),
        Environment NVARCHAR(20),
        IPAddress NVARCHAR(20),
        Timestamp DATETIME2 DEFAULT GETDATE()
    );
END
GO

-- Insert server information
INSERT INTO ServerInfo (ServerName, Environment, IPAddress) 
VALUES ('$env:COMPUTERNAME', '${var.environment}', '$((Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet*)[0].IPAddress)');
GO
"@
    
    $sqlSetupScript | Out-File -FilePath 'C:\\temp\\setup-database.sql' -Encoding UTF8
    
    Write-Host "✅ Fonteyn Database Server setup completed successfully"
    Write-Host "ℹ️ Database setup script saved to C:\\temp\\setup-database.sql"
  SCRIPT
}

# Web Server VMs
resource "azurerm_network_interface" "web" {
  count               = var.web_vm_count
  name                = "nic-${var.project_name}-web-${count.index + 1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "web" {
  count               = var.web_vm_count
  name = substr("vm-${var.project_name}-web${count.index + 1}", 0, 15)
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  # Windows Server licensing
  license_type = var.enable_azure_hybrid_benefit ? "Windows_Server" : null
  
  # VM agent and updates
  provision_vm_agent       = true
  enable_automatic_updates = true
  timezone                = var.timezone

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_server_sku
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "webserver"
    Tier = "frontend"
  })
}

# Install IIS and configure web servers
resource "azurerm_virtual_machine_extension" "web_iis" {
  count                = var.web_vm_count
  name                 = "install-iis-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.web[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${local.web_setup_script}\""
  })

  tags = local.common_tags
}

# Associate web VMs with load balancer
resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count                   = var.web_vm_count
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# App Server VMs
resource "azurerm_network_interface" "app" {
  count               = var.app_vm_count
  name                = "nic-${var.project_name}-app-${count.index + 1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "app" {
  count               = var.app_vm_count
  name                = "vm-${var.project_name}-app-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  license_type = var.enable_azure_hybrid_benefit ? "Windows_Server" : null
  
  provision_vm_agent       = true
  enable_automatic_updates = true
  timezone                = var.timezone

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_server_sku
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "appserver"
    Tier = "backend"
  })
}

# Install application server components
resource "azurerm_virtual_machine_extension" "app_setup" {
  count                = var.app_vm_count
  name                 = "install-dotnet-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.app[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${local.app_setup_script}\""
  })

  tags = local.common_tags
}

# Database Server VM
resource "azurerm_network_interface" "database" {
  name                = "nic-${var.project_name}-database-1"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "database" {
  name                = "vm-${var.project_name}-database-1"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  license_type = var.enable_azure_hybrid_benefit ? "Windows_Server" : null
  
  provision_vm_agent       = true
  enable_automatic_updates = true
  timezone                = var.timezone

  network_interface_ids = [
    azurerm_network_interface.database.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type
    disk_size_gb         = 256  # Database needs more space
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_server_sku
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role = "database"
    Tier = "data"
  })
}

# Install SQL Server on database VM
resource "azurerm_virtual_machine_extension" "database_setup" {
  name                 = "install-sql-express"
  virtual_machine_id   = azurerm_windows_virtual_machine.database.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${local.database_setup_script}\""
  })

  tags = local.common_tags
}

# Domain Join Extensions - Join all VMs to Fonteyn on-premises domain
resource "azurerm_virtual_machine_extension" "domain_join_web" {
  count                = var.domain_join.enabled ? var.web_vm_count : 0
  name                 = "domain-join-web-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.web[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_join.domain_name  # fonteyn.corp
    OUPath  = var.domain_join.ou_path      # OU=Azure-VMs,DC=fonteyn,DC=corp
    User    = "${var.active_directory_netbios}\\${var.admin_username}"  # FONTEYN\azureadmin
    Restart = "true"
    Options = "3"  # Join domain and create computer account
  })

  protected_settings = jsonencode({
    Password = random_password.admin_password.result
  })

  depends_on = [azurerm_virtual_network_gateway_connection.fonteyn_connection]
  tags       = local.common_tags
}

resource "azurerm_virtual_machine_extension" "domain_join_app" {
  count                = var.domain_join.enabled ? var.app_vm_count : 0
  name                 = "domain-join-app-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.app[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_join.domain_name
    OUPath  = var.domain_join.ou_path
    User    = "${var.active_directory_netbios}\\${var.admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = random_password.admin_password.result
  })

  depends_on = [azurerm_virtual_network_gateway_connection.fonteyn_connection]
  tags       = local.common_tags
}

resource "azurerm_virtual_machine_extension" "domain_join_database" {
  count                = var.domain_join.enabled ? 1 : 0
  name                 = "domain-join-database"
  virtual_machine_id   = azurerm_windows_virtual_machine.database.id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_join.domain_name
    OUPath  = var.domain_join.ou_path
    User    = "${var.active_directory_netbios}\\${var.admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = random_password.admin_password.result
  })

  depends_on = [azurerm_virtual_network_gateway_connection.fonteyn_connection]
  tags       = local.common_tags
}

# Antimalware Extension for Windows VMs
resource "azurerm_virtual_machine_extension" "antimalware_web" {
  count                = var.enable_antimalware ? var.web_vm_count : 0
  name                 = "IaaSAntimalware-web-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.web[count.index].id
  publisher            = "Microsoft.Azure.Security"
  type                 = "IaaSAntimalware"
  type_handler_version = "1.3"

  settings = jsonencode({
    AntimalwareEnabled = true
    RealtimeProtectionEnabled = true
    ScheduledScanSettings = {
      isEnabled = true
      scanType = "Quick"
      day = "7"
      time = "120"
    }
  })

  tags = local.common_tags
}

resource "azurerm_virtual_machine_extension" "antimalware_app" {
  count                = var.enable_antimalware ? var.app_vm_count : 0
  name                 = "IaaSAntimalware-app-${count.index + 1}"
  virtual_machine_id   = azurerm_windows_virtual_machine.app[count.index].id
  publisher            = "Microsoft.Azure.Security"
  type                 = "IaaSAntimalware"
  type_handler_version = "1.3"

  settings = jsonencode({
    AntimalwareEnabled = true
    RealtimeProtectionEnabled = true
    ScheduledScanSettings = {
      isEnabled = true
      scanType = "Quick"
      day = "7"
      time = "120"
    }
  })

  tags = local.common_tags
}

resource "azurerm_virtual_machine_extension" "antimalware_database" {
  count                = var.enable_antimalware ? 1 : 0
  name                 = "IaaSAntimalware-database"
  virtual_machine_id   = azurerm_windows_virtual_machine.database.id
  publisher            = "Microsoft.Azure.Security"
  type                 = "IaaSAntimalware"
  type_handler_version = "1.3"

  settings = jsonencode({
    AntimalwareEnabled = true
    RealtimeProtectionEnabled = true
    ScheduledScanSettings = {
      isEnabled = true
      scanType = "Quick"
      day = "7"
      time = "120"
    }
  })

  tags = local.common_tags
}