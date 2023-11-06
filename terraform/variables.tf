variable "resource_group_location" {
  type        = string
  default     = "centralus"
  description = "Location for all resources"
}

variable "resource_group_name_prefix" {
  type        = string
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
  default     = "rg_k8s"
}

variable "username" {
  type        = string
  default     = "azureadmin"
  description = "The username for the local account that will be created on the new VM."
}

variable "password" {
  type        = string
  default     = "Azurek8s+2023"
  description = "The password for the local account that will be created on the new VM."
}

variable "ansible_script_source" {
  description = "Local path to your script"
  type        = string
  default     = "/mnt/d/GitLab/Repos/DevOpsCloudProject/scripts/ansible_installer.sh"
}
variable "master_init_script_source" {
  description = "Local path to your script"
  type        = string
  default     = "/mnt/d/GitLab/Repos/DevOpsCloudProject/scripts/master_kubernetes_init.sh"
}
variable "kubernetes_script_source" {
  description = "Local path to your script"
  type        = string
  default     = "/mnt/d/GitLab/Repos/DevOpsCloudProject/scripts/kubernetes_nodes_setup.sh"
}
variable "docker_script_source" {
  description = "Local path to your script"
  type        = string
  default     = "/mnt/d/GitLab/Repos/DevOpsCloudProject/scripts/docker_installer.sh"
}
variable "ansible_script_destination" {
  description = "Destination path on the VM"
  type        = string
  default     = "/tmp/ansible_installer.sh"
}
variable "master_init_script_destination" {
  description = "Destination path on the VM"
  type        = string
  default     = "/tmp/master_kubernetes_init.sh"
}
variable "kubernetes_script_destination" {
  description = "Destination path on the VM"
  type        = string
  default     = "/tmp/kubernetes_nodes_setup.sh"
}
variable "docker_script_destination" {
  description = "Destination path on the VM"
  type        = string
  default     = "/tmp/docker_installer.sh"
}
variable "scfile" {
  type    = string
  default = "./scripts/ansible_installer.sh"
}