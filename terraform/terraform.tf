terraform {
  backend "remote" {
    organization = "azure-auto-scaler"
    workspaces {
      name = "azure-auto-scaler"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.83.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
