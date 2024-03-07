output "resource_group_name" {
  value = azurerm_resource_group.k8s.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.k8s.name
}

output "sub_name" {
  value = azurerm_subnet.k8s.name
}

output "master_private_ip_address" {
  value = azurerm_linux_virtual_machine.master.private_ip_address
}

output "private_ip_address" {
  value = [for s in azurerm_linux_virtual_machine.worker : s.private_ip_address]
}

output "master_public_ip_address" {
  value = azurerm_linux_virtual_machine.master.public_ip_address
}

output "public_ip_address" {
  value = [for s in azurerm_linux_virtual_machine.worker : s.public_ip_address]
}
