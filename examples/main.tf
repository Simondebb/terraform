terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Ensure you are logged in to Azure, e.g., via Azure CLI `az login`
}

# Variables for the example - users would replace these
variable "example_resource_group_name" {
  description = "Name of an existing Resource Group."
  default     = "your-resource-group-name"
}

variable "example_sql_server_name" {
  description = "Name of your existing Azure SQL Server."
  default     = "your-sqlserver-name"
}

variable "example_database_name" {
  description = "Name of your existing Azure SQL Database."
  default     = "your-database-name"
}

variable "example_admin_login" {
  description = "Admin login for the SQL Server."
  default     = "SqlAdmin"
}

variable "example_admin_password" {
  description = "Admin password for the SQL Server. THIS IS INSECURE. Use environment variables or a secret store in a real scenario."
  type        = string
  sensitive   = true
  default     = "ReplaceWithYourSecurePassword123!"
}

module "sql_users_roles_example" {
  # In a real scenario, you might use a Git source or Terraform Registry source
  source = "../terraform-azuresql-users-roles"

  resource_group_name = var.example_resource_group_name
  server_name         = var.example_sql_server_name
  database_name       = var.example_database_name
  admin_login         = var.example_admin_login
  admin_password      = var.example_admin_password

  roles = ["db_datawriter_example", "db_datareader_example"]

  users = [
    {
      name     = "exampleuser01"
      # Passwords should be strong and ideally managed via a secrets manager
      password = "ExampleUserP@ssw0rd1"
      roles    = ["db_datawriter_example", "db_datareader_example"]
    },
    {
      name     = "exampleuser02"
      password = "ExampleUserP@ssw0rd2"
      roles    = ["db_datareader_example"]
    }
  ]
}

output "managed_user_names" {
  description = "Usernames managed by the module."
  value       = module.sql_users_roles_example.user_names
}

output "managed_role_names" {
  description = "Roles managed by the module."
  value       = module.sql_users_roles_example.role_names_managed
}

output "sql_server_fqdn_from_module" {
  description = "SQL Server FQDN from the module."
  value       = module.sql_users_roles_example.sql_server_fqdn
}
