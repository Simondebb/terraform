# Terraform Azure SQL User and Role Management Module

This Terraform module manages users and roles within an Azure SQL Database. It uses `sqlcmd` executed via `local-exec` provisioners.

The module distinguishes between:
- **Owner Users**: Granted the `db_owner` role automatically.
- **Regular Users**: Assigned specific roles as defined.
- **Custom Roles**: Roles that the module can create if they don't already exist.

## Features

- Creates database users (owners and regular) with specified passwords.
- Updates user passwords if changed in the variables.
- Assigns `db_owner` role to all users defined in `owner_users`.
- Creates custom database roles defined in `custom_roles_to_create` (checks for existence first).
- Assigns specified roles to users defined in `regular_users` (checks for existing membership first).
- Leverages `random_id` to help ensure resources are re-provisioned if passwords or role assignments change.

## Prerequisites

- **Terraform**: Version 1.0 or later.
- **Azure Provider**: Configured for your Azure subscription.
- **`sqlcmd`**: The `sqlcmd` utility must be installed and available in the PATH of the system executing Terraform.
  - For Debian/Ubuntu: `sudo apt-get update && sudo apt-get install -y mssql-tools unixodbc-dev` (add Microsoft's repo first).
  - For other systems, refer to Microsoft's official documentation.
- **Network Connectivity**: The machine running Terraform must have network connectivity to the Azure SQL server.
- **Admin Credentials**: Administrator credentials for the Azure SQL server are required.

## Usage Example

```terraform
module "sql_users_roles" {
  source = "./terraform-azuresql-users-roles" // Or path to module

  resource_group_name = "my-rg"
  server_name         = "my-sqlserver"
  database_name       = "my-database"
  admin_login         = "sqladmin"
  admin_password      = "P@sswOrd123!" // Use a secure method for this!

  custom_roles_to_create = ["application_reader", "application_writer"]

  owner_users = [
    {
      name     = "dbowner01"
      password = "OwnerSecurePassword1!" // Use a secure method
    }
  ]

  regular_users = [
    {
      name     = "appuser01"
      password = "AppUserSecurePassword1!" // Use a secure method
      roles    = ["application_writer", "db_datareader"] // db_datareader is a built-in role
    },
    {
      name     = "reportuser01"
      password = "ReportUserSecurePassword1!" // Use a secure method
      roles    = ["application_reader"]
    }
  ]
}
```

## Inputs

| Name                       | Description                                                                                          | Type                                                                           | Default | Required |
|----------------------------|------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|---------|:--------:|
| `resource_group_name`      | The name of the resource group where the SQL server is located.                                      | `string`                                                                       |         |   yes    |
| `server_name`              | The name of the Azure SQL server.                                                                    | `string`                                                                       |         |   yes    |
| `database_name`            | The name of the Azure SQL database.                                                                  | `string`                                                                       |         |   yes    |
| `admin_login`              | The administrator login for the SQL server.                                                          | `string`                                                                       |         |   yes    |
| `admin_password`           | The administrator password for the SQL server.                                                       | `string` (sensitive)                                                           |         |   yes    |
| `owner_users`              | A list of owner users. These users will be automatically granted the `db_owner` role. Each object has `name` (string) and `password` (string). | `list(object({ name=string, password=string }))`                               | `[]`    |    no    |
| `regular_users`            | A list of regular users. Each object has `name` (string), `password` (string), and `roles` (list of strings for specific role assignments). | `list(object({ name=string, password=string, roles=list(string) }))`          | `[]`    |    no    |
| `custom_roles_to_create`   | A list of custom database roles to be created if they don't exist (e.g., "application_reader"). The `db_owner` role is handled automatically for `owner_users`. | `list(string)`                                                                 | `[]`    |    no    |

## Outputs

| Name                     | Description                                                                               | Type           |
|--------------------------|-------------------------------------------------------------------------------------------|----------------|
| `owner_user_names`       | A list of the owner usernames managed by this module (assigned `db_owner` role).            | `list(string)` |
| `regular_user_names`     | A list of the regular usernames managed by this module.                                   | `list(string)` |
| `custom_roles_created`   | A list of the custom roles defined in the `custom_roles_to_create` variable for creation. | `list(string)` |
| `sql_server_fqdn`        | The fully qualified domain name of the SQL server.                                        | `string`       |
| `sql_database_name`      | The name of the SQL database.                                                             | `string`       |

## Security Considerations

- **Password Management**: Admin and user passwords should be managed securely (e.g., Azure Key Vault, HashiCorp Vault, environment variables) and not hardcoded.
- **`sqlcmd` Execution**: `local-exec` runs commands on the machine executing Terraform. Ensure this environment is secure.
- **Permissions**: Admin credentials have broad permissions.

## Idempotency

The module attempts to be idempotent:
- **User Creation/Update**: `CREATE USER` or `ALTER USER` (for password changes).
- **Role Creation**: Uses `IF NOT EXISTS` for custom roles.
- **Role Assignment**: Uses `IF NOT EXISTS` for role membership.

Failures in `sqlcmd` might taint `null_resource`s, causing re-runs.
