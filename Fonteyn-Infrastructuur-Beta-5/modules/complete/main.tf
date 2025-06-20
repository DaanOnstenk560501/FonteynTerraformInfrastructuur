# main.tf - Core Infrastructure for Testing
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Data sources
data "azurerm_client_config" "current" {}

# Common tags
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "testing"
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Generate SSH key for VM access
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Resource Groups
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# Storage for diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  tags = local.common_tags
}

# Log Analytics for basic monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.common_tags
}