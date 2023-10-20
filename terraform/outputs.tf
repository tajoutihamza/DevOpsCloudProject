output "resource_group_name" {
  value = azurerm_resource_group.rg_k8s.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.vn_k8s.name
}

output "sub_name" {
  value = azurerm_subnet.sub_k8s.name
}

output "azurerm_linux_vm_name" {
  value = [for s in azurerm_linux_virtual_machine.vm_k8s : s.name[*]]
}
output "public_ip_address" {
  value = azurerm_linux_virtual_machine.master_vm.public_ip_address
}