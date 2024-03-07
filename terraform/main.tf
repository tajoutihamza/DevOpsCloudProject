resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "k8s" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

resource "random_pet" "azurerm_vn_name" {
  prefix = "vnet"
}

# Create virtual network
resource "azurerm_virtual_network" "k8s" {
  name                = random_pet.azurerm_vn_name.id
  resource_group_name = azurerm_resource_group.k8s.name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.k8s.location
}

resource "random_pet" "sub_name" {
  prefix = "sub"
}

# Create subnet
resource "azurerm_subnet" "k8s" {
  name                 = random_pet.sub_name.id
  resource_group_name  = azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "random_pet" "public_ip" {
  prefix = "public-ip"
}
# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  count               = 3
  name                = "${random_pet.public_ip.id}-${count.index}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Dynamic"
}

resource "random_pet" "nic_name" {
  prefix = "nic"
}
resource "azurerm_network_interface" "nic" {
  count               = 3
  name                = "${random_pet.nic_name.id}-${count.index}"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name

  ip_configuration {
    name                          = "IpConfiguration"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

resource "random_pet" "nsg_name" {
  prefix = "nsg"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "k8s" {
  name                = random_pet.nsg_name.id
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  security_rule {
    name                       = "allowALL"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_sga" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.k8s.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.k8s.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.k8s.location
  resource_group_name      = azurerm_resource_group.k8s.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "master" {
  name                  = "master-vm"
  location              = azurerm_resource_group.k8s.location
  resource_group_name   = azurerm_resource_group.k8s.name
  network_interface_ids = [azurerm_network_interface.nic[2].id]
  size                  = "Standard_F2s"
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
    name                 = "osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name                   = "master"
  admin_username                  = var.username
  admin_password                  = var.password
  custom_data                     = base64encode(data.template_file.cloud_init.rendered)
  disable_password_authentication = false

  provisioner "remote-exec" {
    inline = [
      "sudo /tmp/install_k8s.sh",
    ]
  }
  connection {
    type     = "ssh"
    user     = var.username
    password = var.password
    host     = self.public_ip_address
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_account.primary_blob_endpoint
  }
}

resource "azurerm_linux_virtual_machine" "worker" {
  count                 = 2
  name                  = "worker${count.index}-vm"
  location              = azurerm_resource_group.k8s.location
  resource_group_name   = azurerm_resource_group.k8s.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
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
    name                 = "osdisk${count.index}"
  }

  admin_username                  = var.username
  admin_password                  = var.password
  computer_name                   = "worker-${count.index}"
  custom_data                     = base64encode(data.template_file.cloud_init.rendered)
  disable_password_authentication = false

  provisioner "remote-exec" {
    inline = [
      "sudo /tmp/install_k8s.sh",
    ]
  }
  connection {
    type     = "ssh"
    user     = var.username
    password = var.password
    host     = self.public_ip_address
  }
}

data "template_file" "cloud_init" {
  template = <<-EOT
  #cloud-config

  write_files:
    - path: /tmp/install_k8s.sh
      permissions: '0755'
      content: |
        #!/bin/bash

        # Install required packages on both master and worker
        echo "=====> starting docker installation <====="
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc;
        do 
            sudo apt-get remove $pkg; 
        done
        # Add Docker's official GPG key:
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Add the repository to Apt sources:
        echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo docker run hello-world
        sudo curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "=====> docker is installed <====="

        echo "=====> starting kubernetes installation <====="
        sudo swapoff -a
        sudo sed -i '/ swap / s/^/#/' /etc/fstab
        cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOF

        sudo modprobe overlay
        sudo modprobe br_netfilter

        # sysctl params required by setup, params persist across reboots
        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOF

        # Apply sysctl params without reboot
        sudo sysctl --system

        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gpg
        sudo mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt install -y kubelet kubeadm kubectl
        sudo mkdir -p /etc/containerd
        sudo sh -c "containerd config default > /etc/containerd/config.toml"
        sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
        sudo systemctl restart containerd.service
        sudo systemctl restart kubelet.service
        sudo systemctl enable kubelet.service
        mkdir -p $HOME/.kube
        echo "=====> kubernetes is installed <====="
        
        echo "=====> starting helm installation <====="
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        sudo apt-get install apt-transport-https --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt-get update
        sudo apt-get install helm
        echo "=====> helm is installed <====="

        echo "=====> adding hostnames into /etc/hosts <====="
        # Add hostnames and ip addresses
        sudo apt-get install sshpass 
        echo "${azurerm_network_interface.nic[2].private_ip_address} master" >> /etc/hosts
        echo "${azurerm_network_interface.nic[0].private_ip_address} worker-0" >> /etc/hosts
        echo "${azurerm_network_interface.nic[1].private_ip_address} worker-1" >> /etc/hosts
        sudo sed -i "/$HOSTNAME/d" /etc/hosts
        echo "=====> hostnames into /etc/hosts added <====="

        # Initialize Kubernetes master (only on the master)
        if hostname | grep -q 'master'; then
          echo "=====> starting master initialization <====="
          sudo kubeadm config images pull
          PRIVATEIP=$(hostname -I | awk '{print $1}')
          sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --control-plane-endpoint "$PRIVATEIP:6443"

          # Configure kubectl for the current user (only on the master)
          sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
          sudo chown $(id -u):$(id -g) $HOME/.kube/config
          kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

          # Generate join command for worker nodes (only on the master)
          kubeadm token create --print-join-command > /tmp/join_command.sh
          echo "=====> master is initialized <====="
          
          echo "=====> starting ansible installation <====="
          sudo apt update
          sudo apt install -y software-properties-common
          sudo add-apt-repository --yes --update ppa:ansible/ansible
          sudo apt install -y ansible
          echo "=====> ansible is installed  <====="
        fi
  EOT
}