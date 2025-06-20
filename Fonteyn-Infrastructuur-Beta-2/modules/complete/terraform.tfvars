# Complete configuratie voor Fonteyn Vakantieparken infrastructuur

# Project configuratie
project_name = "fonteyn-IaC"
location     = "North Europe"

# Email voor alerts
alert_email = "560501@student.fontys.nl"

# VM groottes (pas aan indien gewenst)
vm_size_web = "Standard_D2s_v5"  # Voor web servers
vm_size_app = "Standard_D2s_v5"  # Voor app servers  
vm_size_db  = "Standard_D4s_v5"  # Voor database server

# Netwerk configuratie
vnet_address_space       = "10.0.0.0/16"
frontend_subnet_prefix   = "10.0.1.0/24"
backend_subnet_prefix    = "10.0.2.0/24"
database_subnet_prefix   = "10.0.3.0/24"
management_subnet_prefix = "10.0.4.0/24"

# Tags
tags = {
  Project     = "fonteyn-iac"
  Environment = "complete"
  ManagedBy   = "terraform"
  Owner       = "daan-onstenk"
  CostCenter  = "IT-Development"
  Purpose     = "vacation-parks-infrastructure"
}