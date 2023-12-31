terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "1.9.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.76.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "azurerm" {
  features {}
}
