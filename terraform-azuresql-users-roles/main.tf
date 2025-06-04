data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_sql_server" "main" {
  name                = var.server_name
  resource_group_name = data.azurerm_resource_group.main.name
}

data "azurerm_sql_database" "main" {
  name                = var.database_name
  server_name         = data.azurerm_sql_server.main.name
  resource_group_name = data.azurerm_resource_group.main.name
}

# --- Role Creation ---
resource "null_resource" "create_roles" {
  count = length(var.roles) > 0 ? 1 : 0 # Only run if there are roles to create

  triggers = {
    # Re-run if the list of roles changes
    roles_list = join(",", sort(var.roles))
    db_fqdn    = data.azurerm_sql_server.main.fully_qualified_domain_name
    db_name    = data.azurerm_sql_database.main.name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Attempting to create roles..."
      ${join("
      ", [for role in var.roles :
        "sqlcmd -S ${self.triggers.db_fqdn} -d ${self.triggers.db_name} -U ${var.admin_login} -P \"${var.admin_password}\" -Q \"IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${role}' AND type = 'R') BEGIN CREATE ROLE [${role}]; PRINT 'Role [${role}] created or already exists.'; END ELSE BEGIN PRINT 'Role [${role}] already exists.'; END\""
      ])}
    EOT
    interpreter = ["bash", "-c"]
    # Consider adding error handling or logging here
  }
}

# --- User Creation and Role Assignment ---
resource "random_id" "user_triggers" {
  for_each = { for user in var.users : user.name => user }
  byte_length = 8
  # This resource helps in re-triggering user creation/update if password or roles change
  keepers = {
    password = each.value.password
    roles    = join(",", sort(each.value.roles))
  }
}

resource "null_resource" "manage_user" {
  for_each = { for user in var.users : user.name => user }

  triggers = {
    # Re-run if user-specific details change (password, roles)
    user_config_id = random_id.user_triggers[each.key].hex
    db_fqdn        = data.azurerm_sql_server.main.fully_qualified_domain_name
    db_name        = data.azurerm_sql_database.main.name
    username       = each.value.name
    # Note: Password is not directly used in triggers to avoid logging it,
    # but random_id ensures re-run if it changes.
  }

  # Ensure roles are created before users are managed
  depends_on = [null_resource.create_roles]

  provisioner "local-exec" {
    command = <<EOT
      echo "Managing user [${self.triggers.username}]..."
      # Create or Alter User (SQL Server handles IF EXISTS for CREATE USER, but ALTER USER is used for password changes)
      sqlcmd -S "${self.triggers.db_fqdn}" -d "${self.triggers.db_name}" -U "${var.admin_login}" -P "${var.admin_password}"              -Q "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${self.triggers.username}') BEGIN CREATE USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'User [${self.triggers.username}] created.'; END ELSE BEGIN ALTER USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'User [${self.triggers.username}] password updated.'; END"

      echo "Assigning roles to user [${self.triggers.username}]..."
      ${join("
      ", [for role in each.value.roles :
        "sqlcmd -S \"${self.triggers.db_fqdn}\" -d \"${self.triggers.db_name}\" -U \"${var.admin_login}\" -P \"${var.admin_password}\" -Q \"IF NOT EXISTS (SELECT rp.name as role_principal_name, mp.name as member_principal_name FROM sys.database_role_members drm JOIN sys.database_principals rp ON (drm.role_principal_id = rp.principal_id) JOIN sys.database_principals mp ON (drm.member_principal_id = mp.principal_id) WHERE rp.name = '${role}' AND mp.name = '${self.triggers.username}') BEGIN ALTER ROLE [${role}] ADD MEMBER [${self.triggers.username}]; PRINT 'User [${self.triggers.username}] added to role [${role}].'; END ELSE BEGIN PRINT 'User [${self.triggers.username}] already in role [${role}].'; END\""
      ])}
    EOT
    interpreter = ["bash", "-c"]
    # Consider adding more robust error handling here
    # On failure, Terraform will mark this resource as tainted.
  }
}
