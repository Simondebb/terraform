output "user_names" {
  description = "A list of the usernames managed by this module."
  value       = [for user in var.users : user.name]
}

output "role_names_managed" {
  description = "A list of the roles explicitly defined in the 'roles' variable for creation."
  value       = var.roles
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL server."
  value       = data.azurerm_sql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "The name of the SQL database."
  value       = data.azurerm_sql_database.main.name
}
