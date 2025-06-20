# compute.tf - Windows Server 2022 Virtual Machines

# Generate secure admin password
resource "random_password" "admin_password" {
  length  = 20
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Web Server VMs
resource "azurerm_network_interface" "web" {
  count               = var.web_vm_count
  name                = "nic-web-${count.index + 1}"
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
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  # Enable Azure Hybrid Benefit if you have Windows Server licenses
  license_type = "Windows_Server"
  
  # Enable automatic updates and VM agent
  provision_vm_agent       = true
  enable_automatic_updates = true

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128  # Windows needs more space
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
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

# Install IIS and .NET on web servers
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
  name                = "nic-app-${count.index + 1}"
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
  name                = "vm-app-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  # Enable Azure Hybrid Benefit if you have Windows Server licenses
  license_type = "Windows_Server"
  
  # Enable automatic updates and VM agent
  provision_vm_agent       = true
  enable_automatic_updates = true

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
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

# Install .NET application server on app VMs
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

# Database Server
resource "azurerm_network_interface" "database" {
  name                = "nic-database-1"
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
  name                = "vm-database-1"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result

  # Enable Azure Hybrid Benefit if you have Windows Server licenses
  license_type = "Windows_Server"
  
  # Enable automatic updates and VM agent
  provision_vm_agent       = true
  enable_automatic_updates = true

  network_interface_ids = [
    azurerm_network_interface.database.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256  # Database needs more space
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
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

# Install SQL Server Express on database VM
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

# PowerShell setup scripts
locals {
  web_setup_script = <<-SCRIPT
    # Install IIS with ASP.NET support
    Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Net-Ext45, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Mgmt-Console -IncludeManagementTools
    
    # Install .NET Core Hosting Bundle
    $hostingBundleUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C8-47E9B77CE0F0/dotnet-hosting-6.0.0-win.exe'
    Invoke-WebRequest -Uri $hostingBundleUrl -OutFile 'C:\\dotnet-hosting-bundle.exe'
    Start-Process -FilePath 'C:\\dotnet-hosting-bundle.exe' -ArgumentList '/quiet' -Wait
    
    # Create a simple welcome page
    $welcomePage = @'
<!DOCTYPE html>
<html>
<head>
    <title>Fonteyn Windows Web Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f8ff; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0066cc; }
        .info { background: #e6f3ff; padding: 15px; border-radius: 4px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Fonteyn Windows Web Server</h1>
        <div class="info">
            <p><strong>Server:</strong> $env:COMPUTERNAME</p>
            <p><strong>OS:</strong> Windows Server 2022</p>
            <p><strong>Framework:</strong> .NET Framework 4.8 & .NET Core 6.0</p>
            <p><strong>Web Server:</strong> IIS 10.0</p>
            <p><strong>Timestamp:</strong> $(Get-Date)</p>
        </div>
        <p>This is a test deployment running on Windows Server 2022 with IIS and .NET support.</p>
    </div>
</body>
</html>
'@
    
    $welcomePage | Out-File -FilePath 'C:\\inetpub\\wwwroot\\index.html' -Encoding UTF8
    
    # Restart IIS
    iisreset
  SCRIPT

  app_setup_script = <<-SCRIPT
    # Install .NET Core Runtime
    $runtimeUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C8-47E9B77CE0F0/dotnet-runtime-6.0.0-win-x64.exe'
    Invoke-WebRequest -Uri $runtimeUrl -OutFile 'C:\\dotnet-runtime.exe'
    Start-Process -FilePath 'C:\\dotnet-runtime.exe' -ArgumentList '/quiet' -Wait
    
    # Create application directory
    New-Item -ItemType Directory -Path 'C:\\Apps\\FonteynApp' -Force
    
    # Create a simple .NET console application
    $appCode = @'
using System;
using System.Net;
using System.Text;
using System.Threading.Tasks;

class Program
{
    static async Task Main(string[] args)
    {
        var listener = new HttpListener();
        listener.Prefixes.Add("http://+:8080/");
        listener.Start();
        
        Console.WriteLine("Fonteyn App Server started on port 8080");
        Console.WriteLine("Computer: " + Environment.MachineName);
        Console.WriteLine("Press Ctrl+C to stop");
        
        while (true)
        {
            var context = await listener.GetContextAsync();
            var response = context.Response;
            
            var html = $@"
            <html>
            <body>
                <h1>Fonteyn App Server</h1>
                <p>Hostname: {Environment.MachineName}</p>
                <p>Platform: {Environment.OSVersion}</p>
                <p>Framework: .NET 6.0</p>
                <p>This is the backend application server</p>
                <p>Time: {DateTime.Now}</p>
            </body>
            </html>";
            
            var buffer = Encoding.UTF8.GetBytes(html);
            response.ContentLength64 = buffer.Length;
            response.OutputStream.Write(buffer, 0, buffer.Length);
            response.OutputStream.Close();
        }
    }
}
'@
    
    $appCode | Out-File -FilePath 'C:\\Apps\\FonteynApp\\Program.cs' -Encoding UTF8
    
    # Note: In production, compile and run as a Windows service
    Write-Host "Application server setup completed"
  SCRIPT

  database_setup_script = <<-SCRIPT
    # Download and install SQL Server Express
    $sqlExpressUrl = 'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe'
    Invoke-WebRequest -Uri $sqlExpressUrl -OutFile 'C:\\SQLServerExpress.exe'
    
    # Install SQL Server Express with basic configuration
    Start-Process -FilePath 'C:\\SQLServerExpress.exe' -ArgumentList '/ACTION=Install', '/FEATURES=SQLEngine', '/INSTANCENAME=SQLEXPRESS', '/SQLSVCACCOUNT="NT AUTHORITY\\NETWORK SERVICE"', '/SQLSYSADMINACCOUNTS="BUILTIN\\Administrators"', '/TCPENABLED=1', '/IACCEPTSQLSERVERLICENSETERMS', '/QUIET' -Wait
    
    # Enable SQL Server Browser and start services
    Set-Service -Name 'SQLBrowser' -StartupType Automatic
    Start-Service -Name 'SQLBrowser'
    
    # Configure SQL Server for remote connections
    $sqlCmd = @"
    -- Enable TCP/IP
    EXEC sp_configure 'remote access', 1;
    RECONFIGURE;
    
    -- Create test database
    CREATE DATABASE FonteynTest;
    USE FonteynTest;
    
    -- Create test table
    CREATE TABLE TestData (
        ID int IDENTITY(1,1) PRIMARY KEY,
        ServerName NVARCHAR(50),
        Timestamp DATETIME2 DEFAULT GETDATE()
    );
    
    -- Insert test data
    INSERT INTO TestData (ServerName) VALUES ('$env:COMPUTERNAME');
"@
    
    $sqlCmd | Out-File -FilePath 'C:\\setup-database.sql' -Encoding UTF8
    
    # Note: Execute SQL commands using sqlcmd once SQL Server is fully installed
    Write-Host "Database server setup completed"
  SCRIPT
}