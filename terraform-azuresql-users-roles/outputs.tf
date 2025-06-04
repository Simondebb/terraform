output "owner_user_names" {
  description = "A list of the owner usernames managed by this module (assigned db_owner role)."
  value       = [for user in var.owner_users : user.name]
}

output "regular_user_names" {
  description = "A list of the regular usernames managed by this module."
  value       = [for user in var.regular_users : user.name]
}

output "custom_roles_created" {
  description = "A list of the custom roles defined in 'custom_roles_to_create' variable."
  value       = var.custom_roles_to_create
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL server."
  value       = data.azurerm_sql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "The name of the SQL database."
  value       = data.azurerm_sql_database.main.name
}
