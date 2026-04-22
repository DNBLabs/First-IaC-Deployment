/*
Task 1 provider requirements and baseline provider configuration.
This file declares the Azure provider source and version constraint only.
*/
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
