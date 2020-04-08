provider "azurerm" {
  version = "1.44.0"
}

provider "azuread" {
  version = "0.7.0"
}

provider "random" {
  version = "2.2.1"
}

terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-backend"
    storage_account_name = "tfbackend1"
    container_name       = "tfstate"
    key                  = "nexus.terraform.tfstate"
  }
}