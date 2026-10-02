variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-netiks-store"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "West US 2"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "vm-netiks-store"
}

variable "acr_name" {
  description = "Name of Azure Container Registry"
  type        = string
  default     = "acrnetiksstore"  # Must be globally unique
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "deploy"
}