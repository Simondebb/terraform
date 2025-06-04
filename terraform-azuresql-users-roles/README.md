# Terraform Azure SQL User and Role Management Module

This Terraform module manages users and roles within an Azure SQL Database. It uses `sqlcmd` executed via `local-exec` provisioners to create users, assign passwords, create roles (if they don't exist), and assign users to roles.

## Features

- Creates database users with specified passwords.
- Updates user passwords if changed in the variables.
- Creates database roles (checks for existence first).
- Assigns users to specified database roles (checks for existing membership first).
- Leverages `random_id` to ensure user resources are re-provisioned if passwords or role assignments change.

## Prerequisites

- **Terraform**: Version 1.0 or later.
- **Azure Provider**: Configured for your Azure subscription.
- **`sqlcmd`**: The `sqlcmd` utility must be installed and available in the PATH of the system executing Terraform. This module relies on `sqlcmd` to interact with the Azure SQL Database.
  - For Debian/Ubuntu: `sudo apt-get update && sudo apt-get install -y mssql-tools unixodbc-dev` (you might also need to add Microsoft's package repository).
  - For other systems, please refer to Microsoft's official documentation for installing `sqlcmd`.
- **Network Connectivity**: The machine running Terraform must have network connectivity to the Azure SQL server.
- **Admin Credentials**: You need administrator credentials for the Azure SQL server to create users and roles.

## Usage Example

```terraform
module "sql_users_roles" {
  source = "./terraform-azuresql-users-roles" // Or path to module in registry/git

  resource_group_name = "my-rg"
  server_name         = "my-sqlserver"
  database_name       = "my-database"
  admin_login         = "sqladmin"
  admin_password      = "P@sswOrd123!" // Use a secure way to manage this

  roles = ["db_developer", "db_reader_writer"]

  users = [
    {
      name     = "appuser01"
      password = "SecurePassword1!" // Use a secure way to manage this
      roles    = ["db_developer", "db_reader_writer"]
    },
    {
      name     = "readonlyuser01"
      password = "AnotherSecurePassword1!" // Use a secure way to manage this
      roles    = ["db_datareader"] // Assuming db_datareader role exists or is created by another process if not in 'roles' var
    }
  ]
}
```

## Inputs

| Name                  | Description                                                                 | Type                                                                 | Default | Required |
|-----------------------|-----------------------------------------------------------------------------|----------------------------------------------------------------------|---------|:--------:|
| `resource_group_name` | The name of the resource group where the SQL server is located.             | `string`                                                             |         |   yes    |
| `server_name`         | The name of the Azure SQL server.                                           | `string`                                                             |         |   yes    |
| `database_name`       | The name of the Azure SQL database.                                         | `string`                                                             |         |   yes    |
| `admin_login`         | The administrator login for the SQL server.                                 | `string`                                                             |         |   yes    |
| `admin_password`      | The administrator password for the SQL server.                              | `string` (sensitive)                                                 |         |   yes    |
| `users`               | A list of user objects to be created in the database.                       | `list(object({ name=string, password=string, roles=list(string) }))` | `[]`    |    no    |
| `roles`               | A list of database roles to be created (if they don't already exist).       | `list(string)`                                                       | `[]`    |    no    |

## Outputs

| Name                 | Description                                                                          | Type           |
|----------------------|--------------------------------------------------------------------------------------|----------------|
| `user_names`         | A list of the usernames managed by this module.                                      | `list(string)` |
| `role_names_managed` | A list of the roles explicitly defined in the 'roles' variable for creation.         | `list(string)` |
| `sql_server_fqdn`    | The fully qualified domain name of the SQL server.                                   | `string`       |
| `sql_database_name`  | The name of the SQL database.                                                        | `string`       |

## Security Considerations

- **Password Management**: Admin and user passwords are provided as variables. It is highly recommended to use a secure method for managing these secrets, such as Azure Key Vault, HashiCorp Vault, or environment variables, rather than hardcoding them in your Terraform configuration. The `admin_password` and user passwords within the `users` variable are marked as sensitive where appropriate.
- **`sqlcmd` Execution**: This module uses `local-exec` which runs commands on the machine where Terraform is executed. Ensure this environment is secure.
- **Permissions**: The admin credentials provided will have broad permissions on the SQL server. Scope these permissions appropriately if possible, though user/role management typically requires high privileges.

## Idempotency

The module attempts to be idempotent:
- **User Creation**: `CREATE USER` is used. If the user exists, `ALTER USER` is used to update the password.
- **Role Creation**: Checks if a role exists using `IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '...' AND type = 'R')` before attempting `CREATE ROLE`.
- **Role Assignment**: Checks if a user is already a member of a role using `IF NOT EXISTS (SELECT ... FROM sys.database_role_members ...)` before attempting `ALTER ROLE ... ADD MEMBER`.

If `sqlcmd` commands fail for any reason, Terraform might mark the `null_resource` as tainted and attempt to re-run it on the next apply. More sophisticated error handling within the scripts might be required for production environments.
