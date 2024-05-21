# Provider configuration
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    tfe = {
      source = "hashicorp/tfe"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

locals {
  tags = {
    name = var.name
    environment = var.environment
  }
}

data "tfe_outputs" "rgvnet" {
  organization = var.organization
  workspace    = var.workspace
}

# Random ID for resource naming
resource "random_id" "webserver_id" {
  byte_length = 8
}

# Create Public IP Address
resource "azurerm_public_ip" "webserver-ip" {
  name                = "${var.name}-ip-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name
  allocation_method   = "Static"
  tags                = local.tags
}

# Create Network Interface
resource "azurerm_network_interface" "webserver-nic" {
  name                = "${var.name}-nic-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.tfe_outputs.rgvnet.nonsensitive_values.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webserver-ip.id
  }
    tags = local.tags
}

# Security group to allow inbound webtraffic
resource "azurerm_network_security_group" "webserver-sg" {
  name                = "${var.name}-sg-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name

  security_rule {
    name                       = "${var.name}-sg-rule-${random_id.webserver_id.hex}"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = local.tags
}

# Subnet/Security Group assocication
resource "azurerm_subnet_network_security_group_association" "webserver-sg-association" {
  subnet_id                 = data.tfe_outputs.rgvnet.nonsensitive_values.subnet_id
  network_security_group_id = azurerm_network_security_group.webserver-sg.id
}

# Setup Azure Webserver
resource "azurerm_linux_virtual_machine" "webserver-vm" {
  name                = "${var.name}-vm-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.webserver-nic.id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.pub_ssh_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(
    <<CUSTOM_DATA
#!/bin/bash
echo "<h1>Azure Terraform Webserver </br> ${var.name}-vm-${random_id.webserver_id.hex}<h1>" > index.html
nohup busybox httpd -f -p 80 &
#write out current crontab
crontab -l > mycron
#echo new cron into cron file
echo "@reboot sleep 300 && nohup busybox httpd -f -p 80 -h / &" >> mycron
#install new cron file
crontab mycron
rm mycron
CUSTOM_DATA
  )
tags = local.tags
}
