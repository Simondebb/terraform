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

variable "users" {
  description = "A list of user objects to be created in the database."
  type = list(object({
    name     = string
    password = string
    roles    = list(string)
  }))
  default = []
}

variable "roles" {
  description = "A list of database roles to be created (if they don't already exist)."
  type        = list(string)
  default     = []
}

variable "resource_group_name" {
  description = "The name of the resource group where the SQL server is located."
  type        = string
}
