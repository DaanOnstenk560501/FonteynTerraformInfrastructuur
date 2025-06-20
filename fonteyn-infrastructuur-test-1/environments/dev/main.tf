# Dit gebruikt de networking module om een netwerk te maken

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Gebruik de networking module
module "networking" {
  source = "../../modules/networking"
  
  # Geef instellingen door aan de module
  project_name = "fonteyn"
  location     = "West Europe"
  
  tags = {
    Environment = "dev"
    Project     = "fonteyn-iac"
    Owner       = "daan-onstenk"
  }
}

# Toon resultaten
output "network_info" {
  value = {
    vnet_name          = module.networking.vnet_name
    frontend_subnet_id = module.networking.frontend_subnet_id
    backend_subnet_id  = module.networking.backend_subnet_id
  }
}