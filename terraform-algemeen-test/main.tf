terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Stap 2: Configureer de Azure provider
provider "azurerm" {
  features {}
}

# Stap 3: Maak een resource group aan
resource "azurerm_resource_group" "mijn_eerste_rg" {
  name     = "rg-mijn-eerste-test"
  location = "West Europe"
  
  tags = {
    Environment = "learning"
    Project     = "terraform-basics"
  }
}