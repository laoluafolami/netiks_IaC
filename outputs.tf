output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = module.compute.public_ip_address
}

output "acr_login_server" {
  description = "Login server URL for ACR"
  value       = module.registry.login_server
}

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = "ssh ${var.admin_username}@${module.compute.public_ip_address}"
}