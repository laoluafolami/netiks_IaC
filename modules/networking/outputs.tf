output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.internal.id
}

output "security_group_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.main.id
}