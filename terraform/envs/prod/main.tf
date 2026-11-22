terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Connection details are passed with -backend-config (see the workflows).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

module "platform" {
  source = "../../modules/platform"

  project         = "aksgitops"
  environment     = "prod"
  location        = "centralindia"
  vnet_cidr       = "10.20.0.0/16"
  aks_subnet_cidr = "10.20.0.0/22"
  aks_sku_tier    = "Standard"
  node_vm_size    = "Standard_B2s_v2"
  node_count      = 2
  user_node_count = 1
  alert_email     = var.alert_email
}
