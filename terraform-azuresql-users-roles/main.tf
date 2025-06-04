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

# --- Custom Role Creation ---
resource "null_resource" "create_custom_roles" {
  count = length(var.custom_roles_to_create) > 0 ? 1 : 0

  triggers = {
    roles_list = join(",", sort(var.custom_roles_to_create))
    db_fqdn    = data.azurerm_sql_server.main.fully_qualified_domain_name
    db_name    = data.azurerm_sql_database.main.name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Attempting to create custom roles..."
      ${join("
      ", [for role in var.custom_roles_to_create :
        "sqlcmd -S ${self.triggers.db_fqdn} -d ${self.triggers.db_name} -U ${var.admin_login} -P \"${var.admin_password}\" -Q \"IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${role}' AND type = 'R') BEGIN CREATE ROLE [${role}]; PRINT 'Custom role [${role}] created.'; END ELSE BEGIN PRINT 'Custom role [${role}] already exists.'; END\""
      ])}
    EOT
    interpreter = ["bash", "-c"]
  }
}

# --- Owner User Creation and db_owner Assignment ---
resource "random_id" "owner_user_triggers" {
  for_each = { for user in var.owner_users : user.name => user }
  byte_length = 8
  keepers = {
    password = each.value.password
  }
}

resource "null_resource" "manage_owner_user" {
  for_each = { for user in var.owner_users : user.name => user }

  triggers = {
    user_config_id = random_id.owner_user_triggers[each.key].hex
    db_fqdn        = data.azurerm_sql_server.main.fully_qualified_domain_name
    db_name        = data.azurerm_sql_database.main.name
    username       = each.value.name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Managing owner user [${self.triggers.username}]..."
      # Create or Alter User
      sqlcmd -S "${self.triggers.db_fqdn}" -d "${self.triggers.db_name}" -U "${var.admin_login}" -P "${var.admin_password}"              -Q "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${self.triggers.username}') BEGIN CREATE USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'Owner user [${self.triggers.username}] created.'; END ELSE BEGIN ALTER USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'Owner user [${self.triggers.username}] password updated.'; END"

      echo "Assigning 'db_owner' role to user [${self.triggers.username}]..."
      sqlcmd -S "${self.triggers.db_fqdn}" -d "${self.triggers.db_name}" -U "${var.admin_login}" -P "${var.admin_password}"              -Q "IF NOT EXISTS (SELECT rp.name as role_principal_name, mp.name as member_principal_name FROM sys.database_role_members drm JOIN sys.database_principals rp ON (drm.role_principal_id = rp.principal_id) JOIN sys.database_principals mp ON (drm.member_principal_id = mp.principal_id) WHERE rp.name = 'db_owner' AND mp.name = '${self.triggers.username}') BEGIN ALTER ROLE [db_owner] ADD MEMBER [${self.triggers.username}]; PRINT 'User [${self.triggers.username}] added to role [db_owner].'; END ELSE BEGIN PRINT 'User [${self.triggers.username}] already in role [db_owner].'; END"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# --- Regular User Creation and Role Assignment ---
resource "random_id" "regular_user_triggers" {
  for_each = { for user in var.regular_users : user.name => user }
  byte_length = 8
  keepers = {
    password = each.value.password
    roles    = join(",", sort(each.value.roles))
  }
}

resource "null_resource" "manage_regular_user" {
  for_each = { for user in var.regular_users : user.name => user }

  triggers = {
    user_config_id = random_id.regular_user_triggers[each.key].hex
    db_fqdn        = data.azurerm_sql_server.main.fully_qualified_domain_name
    db_name        = data.azurerm_sql_database.main.name
    username       = each.value.name
  }

  depends_on = [null_resource.create_custom_roles] # Ensure custom roles are created first

  provisioner "local-exec" {
    command = <<EOT
      echo "Managing regular user [${self.triggers.username}]..."
      # Create or Alter User
      sqlcmd -S "${self.triggers.db_fqdn}" -d "${self.triggers.db_name}" -U "${var.admin_login}" -P "${var.admin_password}"              -Q "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '${self.triggers.username}') BEGIN CREATE USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'Regular user [${self.triggers.username}] created.'; END ELSE BEGIN ALTER USER [${self.triggers.username}] WITH PASSWORD = '${each.value.password}'; PRINT 'Regular user [${self.triggers.username}] password updated.'; END"

      echo "Assigning roles to regular user [${self.triggers.username}]..."
      ${join("
      ", [for role in each.value.roles :
        "sqlcmd -S \"${self.triggers.db_fqdn}\" -d \"${self.triggers.db_name}\" -U \"${var.admin_login}\" -P \"${var.admin_password}\" -Q \"IF NOT EXISTS (SELECT rp.name as role_principal_name, mp.name as member_principal_name FROM sys.database_role_members drm JOIN sys.database_principals rp ON (drm.role_principal_id = rp.principal_id) JOIN sys.database_principals mp ON (drm.member_principal_id = mp.principal_id) WHERE rp.name = '${role}' AND mp.name = '${self.triggers.username}') BEGIN ALTER ROLE [${role}] ADD MEMBER [${self.triggers.username}]; PRINT 'User [${self.triggers.username}] added to role [${role}].'; END ELSE BEGIN PRINT 'User [${self.triggers.username}] already in role [${role}].'; END\""
      ])}
    EOT
    interpreter = ["bash", "-c"]
  }
}
