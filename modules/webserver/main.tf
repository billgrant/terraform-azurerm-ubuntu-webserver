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

data "tfe_outputs" "rgvnet" {
  organization = var.organization
  workspace    = var.workspace
}

# Random ID for resource naming
resource "random_id" "webserver_id" {
  byte_length = 8
}

# Random ID for security group priority
resource "random_integer" "webserver_sg_priority" {
  min = 101
  max = 4096  
}

# Create Public IP Address
resource "azurerm_public_ip" "webserver-ip" {
  name                = "${var.tags["name"]}-ip-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name
  allocation_method   = "Static"
  tags                = var.tags
}

# Create Network Interface
resource "azurerm_network_interface" "webserver-nic" {
  name                = "${var.tags["name"]}-nic-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.tfe_outputs.rgvnet.nonsensitive_values.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webserver-ip.id
  }
  tags = var.tags
}

# Allow SSH traffic
resource "azurerm_network_security_rule" "webserver-ssh" {
  name                        = "${var.tags["name"]}-nsr-${random_id.webserver_id.hex}"
  priority                    = random_integer.webserver_sg_priority.result
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "${azurerm_public_ip.webserver-ip.ip_address}/32"
  resource_group_name         = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name
  network_security_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.security_group_name
}

# Setup Azure Webserver
resource "azurerm_linux_virtual_machine" "webserver-vm" {
  name                = "${var.tags["name"]}-vm-${random_id.webserver_id.hex}"
  location            = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_location
  resource_group_name = data.tfe_outputs.rgvnet.nonsensitive_values.resource_group_name
  size                = var.vm_size
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
apt install nginx
service nginx stop
rm /var/www/html/*
echo "<h1>Azure Terraform Webserver </br> ${var.tags["name"]}-vm-${random_id.webserver_id.hex}</h1>" > /var/www/html/index.html
service nginx start
CUSTOM_DATA
  )
  tags = var.tags
}
