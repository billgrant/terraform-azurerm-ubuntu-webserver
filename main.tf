# This is the main file that will be used to call the module

# Required provider block for NO-CODE module
provider "azurerm" {
  features {}
}
module "webserver" {
  source       = "./modules/webserver"
  organization = var.organization
  workspace    = var.workspace
  pub_ssh_key  = var.pub_ssh_key
  name         = var.name
  environment  = var.environment
}