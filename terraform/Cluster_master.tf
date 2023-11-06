# Create public IPs
resource "azurerm_public_ip" "master_public_ip" {
  name                = "masterPublicIP"
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "master_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "master_nic" {
  name                = "masterNIC"
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.sub_k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.master_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "master_nic_sga" {
  network_interface_id      = azurerm_network_interface.master_nic.id
  network_security_group_id = azurerm_network_security_group.master_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg_k8s.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "master_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg_k8s.location
  resource_group_name      = azurerm_resource_group.rg_k8s.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "master_vm" {
  name                  = "masterVM"
  location              = azurerm_resource_group.rg_k8s.location
  resource_group_name   = azurerm_resource_group.rg_k8s.name
  network_interface_ids = [azurerm_network_interface.master_nic.id]
  size                  = "Standard_F2s"

  os_disk {
    name                 = "masterOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "masterk8s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = "false"
  # admin_ssh_key {
  #   username   = var.username
  #   public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  # }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.master_account.primary_blob_endpoint
  }

  provisioner "file" {

    source      = var.docker_script_source
    destination = var.docker_script_destination
  }
  provisioner "file" {

    source      = var.ansible_script_source
    destination = var.ansible_script_destination
  }
  provisioner "file" {

    source      = var.kubernetes_script_source
    destination = var.kubernetes_script_destination
  }
  provisioner "file" {

    source      = var.master_init_script_source
    destination = var.master_init_script_destination
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/*.sh",
      "sudo /tmp/ansible_installer.sh",
      "sudo /tmp/docker_installer.sh",
      "sudo /tmp/kubernetes_nodes_setup.sh",
      "sudo /tmp/master_kubernetes_init.sh",
    ]
  }
  connection {
    type     = "ssh"
    user     = var.username
    password = var.password
    host     = azurerm_linux_virtual_machine.master_vm.public_ip_address
  }

}
