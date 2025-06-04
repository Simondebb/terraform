variable "server_name" {
  description = "The name of the Azure SQL server."
  type        = string
}

variable "database_name" {
  description = "The name of the Azure SQL database."
  type        = string
}

variable "admin_login" {
  description = "The administrator login for the SQL server."
  type        = string
}

variable "admin_password" {
  description = "The administrator password for the SQL server."
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "The name of the resource group where the SQL server is located."
  type        = string
}

variable "owner_users" {
  description = "A list of owner users to be created. These users will be granted the 'db_owner' role."
  type = list(object({
    name     = string
    password = string
  }))
  default = []
}

variable "regular_users" {
  description = "A list of regular users to be created with specific role assignments."
  type = list(object({
    name     = string
    password = string
    roles    = list(string)
  }))
  default = []
}

variable "custom_roles_to_create" {
  description = "A list of custom database roles to be created (e.g., 'application_reader', 'web_writer'). The 'db_owner' role is handled automatically for owner_users."
  type        = list(string)
  default     = []
}
