# compute.tf - Virtual Machines

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

resource "azurerm_linux_virtual_machine" "web" {
  count               = var.web_vm_count
  name                = "vm-web-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  # Simple web server setup
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Create a simple index page
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Fonteyn Test Web Server</title>
    </head>
    <body>
        <h1>Welcome to Fonteyn Web Server ${count.index + 1}</h1>
        <p>This is a test deployment</p>
        <p>Server IP: $(hostname -I)</p>
        <p>Timestamp: $(date)</p>
    </body>
    </html>
HTML
  EOF
  )

  tags = merge(local.common_tags, {
    Role = "webserver"
    Tier = "frontend"
  })
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

resource "azurerm_linux_virtual_machine" "app" {
  count               = var.app_vm_count
  name                = "vm-app-${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  # Simple app server setup
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip
    
    # Create a simple Python web app
    cat > /home/${var.admin_username}/app.py << 'PYTHON'
import http.server
import socketserver
import socket

PORT = 8080

class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        hostname = socket.gethostname()
        ip = socket.gethostbyname(hostname)
        html = f"""
        <html>
        <body>
            <h1>Fonteyn App Server ${count.index + 1}</h1>
            <p>Hostname: {hostname}</p>
            <p>IP: {ip}</p>
            <p>This is the backend application server</p>
        </body>
        </html>
        """
        self.wfile.write(html.encode())

with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
    print(f"Server running on port {PORT}")
    httpd.serve_forever()
PYTHON

    # Start the app (in production, use systemd service)
    nohup python3 /home/${var.admin_username}/app.py &
  EOF
  )

  tags = merge(local.common_tags, {
    Role = "appserver"
    Tier = "backend"
  })
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

resource "azurerm_linux_virtual_machine" "database" {
  name                = "vm-database-1"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.database.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  # Install MySQL
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y mysql-server
    
    # Basic MySQL setup (for testing only!)
    mysql -e "CREATE DATABASE fonteyn_test;"
    mysql -e "CREATE USER 'testuser'@'%' IDENTIFIED BY 'testpass123';"
    mysql -e "GRANT ALL PRIVILEGES ON fonteyn_test.* TO 'testuser'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Allow remote connections (testing only!)
    sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    systemctl restart mysql
    systemctl enable mysql
  EOF
  )

  tags = merge(local.common_tags, {
    Role = "database"
    Tier = "data"
  })
}