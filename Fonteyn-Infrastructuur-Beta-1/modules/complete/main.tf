# Complete Fonteyn Vakantieparken infrastructuur

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Data sources
data "azurerm_subscription" "current" {}

# Lokale variabelen
locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "daan-onstenk"
    Purpose     = "fonteyn-iac-complete"
  })
}

# Wachtwoord genereren voor SQL Server
resource "random_password" "sql_admin" {
  length  = 16
  special = true
}

# SSH key pair genereren (in productie zou je je eigen key gebruiken)
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 1. Networking Module
module "networking" {
  source = "../../modules/networking"
  
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
  
  # Netwerk configuratie
  vnet_address_space       = var.vnet_address_space
  frontend_subnet_prefix   = var.frontend_subnet_prefix
  backend_subnet_prefix    = var.backend_subnet_prefix
  database_subnet_prefix   = var.database_subnet_prefix
  management_subnet_prefix = var.management_subnet_prefix
}

# 2. Storage Module
module "storage" {
  source = "../../modules/storage"
  
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
  
  # SQL configuratie
  sql_admin_username = "sqladmin"
  sql_admin_password = random_password.sql_admin.result
  
  # Netwerk toegang
  vnet_address_start = "10.0.0.0"
  vnet_address_end   = "10.0.255.255"
}

# 3. Security Module
module "security" {
  source = "../../modules/security"
  
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
  
  # Geheimen
  sql_admin_password   = random_password.sql_admin.result
  storage_account_key  = module.storage.storage_account_primary_access_key
}

# 4. Compute Module
module "compute" {
  source = "../../modules/compute"
  
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
  
  # Netwerk configuratie
  frontend_subnet_id = module.networking.frontend_subnet_id
  backend_subnet_id  = module.networking.backend_subnet_id
  database_subnet_id = module.networking.database_subnet_id
  
  # VM configuratie
  vm_size_web = var.vm_size_web
  vm_size_app = var.vm_size_app
  vm_size_db  = var.vm_size_db
  
  # SSH configuratie
  admin_username        = "azureuser"
  ssh_public_key       = tls_private_key.ssh.public_key_openssh
  storage_account_uri  = module.storage.diagnostics_storage_account_uri
  
  depends_on = [module.networking, module.storage]
}

# 5. Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
  
  # Monitoring configuratie
  alert_email     = var.alert_email
  subscription_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  
  # VM IDs voor monitoring
  vm_ids = concat(
    module.compute.web_vm_ids,
    module.compute.app_vm_ids,
    [module.compute.db_vm_id]
  )
  
  depends_on = [module.compute]
}

# Outputs voor overzicht
output "infrastructure_summary" {
  description = "Overzicht van de aangemaakte infrastructuur"
  value = {
    # Netwerk informatie
    vnet_name          = module.networking.vnet_name
    resource_groups = {
      network    = module.networking.network_resource_group_name
      compute    = module.compute.compute_resource_group_name
      storage    = module.storage.storage_resource_group_name
      security   = module.security.security_resource_group_name
      monitoring = module.monitoring.monitoring_resource_group_name
    }
    
    # VM informatie
    load_balancer_ip = module.compute.load_balancer_public_ip
    web_servers = {
      private_ips = module.compute.web_vm_private_ips
    }
    app_servers = {
      private_ips = module.compute.app_vm_private_ips
    }
    database_server = {
      private_ip = module.compute.db_vm_private_ip
    }
    
    # Database informatie
    storage_table = module.storage.storage_table_name
    
    # Security informatie
    key_vault_name = module.security.key_vault_name
    
    # Monitoring informatie
    log_analytics_workspace = module.monitoring.log_analytics_workspace_name
  }
}

# SSH private key output (voor connectie naar VMs)
output "ssh_private_key" {
  description = "SSH private key voor verbinding met VMs"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

# Storage Table connection info
output "storage_connection_info" {
  description = "Storage Table connectie informatie"
  value = {
    storage_account = module.storage.storage_account_name
    table_name     = module.storage.storage_table_name
  }
}