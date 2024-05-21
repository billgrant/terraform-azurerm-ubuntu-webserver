output "webserver_name" {
  value = azurerm_linux_virtual_machine.webserver-vm.name
}

output "webserver_public_ip" {
  value = azurerm_public_ip.webserver-ip.ip_address
}