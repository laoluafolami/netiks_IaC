terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Networking Module
module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
}

# Compute Module  
module "compute" {
  source              = "./modules/compute"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  subnet_id          = module.networking.subnet_id
  vm_name            = var.vm_name
  admin_username     = var.admin_username
}

# Container Registry Module
module "registry" {
  source              = "./modules/registry"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  acr_name           = var.acr_name
}