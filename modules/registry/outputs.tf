output "login_server" {
  description = "Login server URL"
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "Admin username"
  value       = azurerm_container_registry.main.admin_username
}

output "admin_password" {
  description = "Admin password"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}