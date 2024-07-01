provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_mariadb_server" "example" {
  name                = "example-mariadb-server"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name

  administrator_login          = "mariadbadmin"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "10.2"

  auto_grow_enabled                = true
  backup_retention_days            = 7
  geo_redundant_backup_enabled     = false
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}