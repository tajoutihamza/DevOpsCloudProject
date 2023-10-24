resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg_k8s" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

resource "random_pet" "azurerm_vn_name" {
  prefix = "vnet"
}

# Create virtual network
resource "azurerm_virtual_network" "vn_k8s" {
  name                = random_pet.azurerm_vn_name.id
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name
}

resource "random_pet" "sub_name" {
  prefix = "sub"
}

# Create subnet
resource "azurerm_subnet" "sub_k8s" {
  name                 = random_pet.sub_name.id
  resource_group_name  = azurerm_resource_group.rg_k8s.name
  virtual_network_name = azurerm_virtual_network.vn_k8s.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "second_public_ip" {
  count               = 2
  name                = "secondPublicIP${count.index}"
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic_k8s" {
  count               = 2
  name                = "secondNIC${count.index}"
  location            = azurerm_resource_group.rg_k8s.location
  resource_group_name = azurerm_resource_group.rg_k8s.name

  ip_configuration {
    name                          = "IpConfiguration"
    subnet_id                     = azurerm_subnet.sub_k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.second_public_ip[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "second_nic_sga" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.nic_k8s[count.index].id
  network_security_group_id = azurerm_network_security_group.master_nsg.id
}

resource "random_pet" "azurerm_linux_vm_name" {
  prefix = "vm"
}

resource "azurerm_linux_virtual_machine" "vm_k8s" {
  count                 = 2
  name                  = "${random_pet.azurerm_linux_vm_name.id}${count.index}"
  location              = azurerm_resource_group.rg_k8s.location
  resource_group_name   = azurerm_resource_group.rg_k8s.name
  network_interface_ids = [azurerm_network_interface.nic_k8s[count.index].id]
  size                  = "Standard_B2s"
  # delete_data_disks_on_termination = true
  # delete_os_disk_on_termination = true

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  # admin_ssh_key {
  #   username   = var.username
  #   public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).public_key
  # }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "secondosdisks${count.index}"
  }

  computer_name                   = "secondk8s${count.index}"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = "false"

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.master_account.primary_blob_endpoint
  }
}