#TERRAFORM-AZURERM-UBUNTU-WEBSERVER

This module creates a Ubuntu 22.04 LTS Azure VM.

The module is for HCP Terraform demo/lab purposes. The module is designed for the HCP Terraform private registry. The main/parent module is only used for No-Code deployments. The submodule `webserver` should be used for all other run types.

There is a single variable that accepts the Vnet CIDR.
