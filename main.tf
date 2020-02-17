data "azurerm_client_config" "current" {}

resource "azuread_application" "app_nexus" {
  name = "${var.app_name}"
}

resource "azurerm_resource_group" "rg_nexus" {
  name     = "${var.app_name}-rg"
  location = "${var.location}"
}

# Create the Service Principal for the application
resource "azuread_service_principal" "sp_ado" {
  application_id = "${azuread_application.app_nexus.application_id}"
}

#Create a random password for the SP
resource "random_password" "password_sp_ado" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azuread_service_principal_password" "sp_password_ado" {
  service_principal_id = "${azuread_service_principal.sp_ado.id}"
  value                = "${random_password.password_sp_ado.result}"
  end_date             = "3000-01-01T0:00:00Z"
}

# Create the storage account that will store Terraform state
resource "azurerm_storage_account" "sa_tfstate" {
  name                     = "jpmnexus${lower(var.app_name)}"
  resource_group_name      = "${azurerm_resource_group.rg_nexus.name}"
  location                 = "${azurerm_resource_group.rg_nexus.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "sacontainer_tfstate" {
  name = "tfstate"
  storage_account_name = "${azurerm_storage_account.sa_tfstate.name}"
  container_access_type = "blob"
}

# Create the key vault and store the SA and SP secrets
resource "azurerm_key_vault" "kv_nexus" {
  name                = "jpm-${lower(var.app_name)}-kv"
  location            = "${azurerm_resource_group.rg_nexus.location}"
  resource_group_name = "${azurerm_resource_group.rg_nexus.name}"
  tenant_id           = "${data.azurerm_client_config.current.tenant_id}"
  sku_name            = "Standard"

  access_policy {
      tenant_id = "${data.azurerm_client_config.current.tenant_id}"
      object_id = "${data.azurerm_client_config.current.object_id}"

      secret_permissions = [
        "list",
        "get",
        "set",
        "delete"
      ]
  }

  access_policy {
      tenant_id = "${data.azurerm_client_config.current.tenant_id}"
      object_id = "${azuread_service_principal.sp_ado.id}"

      secret_permissions = ["get"]
  }
}

resource "azurerm_key_vault_secret" "kv_secret_sa" {
  name         = "sa-tfstate"
  value        = "${azurerm_storage_account.sa_tfstate.primary_access_key}"
  key_vault_id = "${azurerm_key_vault.kv_nexus.id}"
}

resource "azurerm_key_vault_secret" "kv_secret_sp_client_id" {
  name         = "sp-ado-client-id"
  value        = "${azuread_service_principal.sp_ado.application_id}"
  key_vault_id = "${azurerm_key_vault.kv_nexus.id}"
}

resource "azurerm_key_vault_secret" "kv_secret_sp_client_secret" {
  name         = "sp-ado-client-secret"
  value        = "${azuread_service_principal_password.sp_password_ado.value}"
  key_vault_id = "${azurerm_key_vault.kv_nexus.id}"
}

resource "azurerm_key_vault_secret" "kv_secret_sp_tenant_id" {
  name         = "sp-ado-tenant-id"
  value        = "${data.azurerm_client_config.current.tenant_id}"
  key_vault_id = "${azurerm_key_vault.kv_nexus.id}"
}

resource "azurerm_key_vault_secret" "kv_secret_sp_subscription_id" {
  name         = "sp-ado-subscription-id"
  value        = "${data.azurerm_client_config.current.subscription_id}"
  key_vault_id = "${azurerm_key_vault.kv_nexus.id}"
}

# Grant ADO access to the Key Vault and Storage Account
resource "azurerm_role_assignment" "role_assignment_ado_keyvault" {
  principal_id         = "${azuread_service_principal.sp_ado.id}"
  scope                = "${azurerm_key_vault.kv_nexus.id}"
  role_definition_name = "Reader"
}

resource "azurerm_role_assignment" "role_assignment_ado_sa" {
  principal_id         = "${azuread_service_principal.sp_ado.id}"
  scope                = "${azurerm_storage_account.sa_tfstate.id}"
  role_definition_name = "Contributor"
}

resource "azurerm_role_assignment" "role_assignment_ado_rg" {
  principal_id         = "${azuread_service_principal.sp_ado.id}"
  scope                = "${azurerm_resource_group.rg_nexus.id}"
  role_definition_name = "Contributor"
}

# Create the Azure DevOps Project
# Depends on the environment variables AZDO_PERSONAL_ACCESS_TOKEN and AZDO_ORG_SERVICE_URL
resource "azuredevops_project" "ado_project" {
    depends_on         = ["azuread_service_principal.sp_ado"]
    project_name       = "${var.app_name}"
    description        = "enter description"
    visibility         = "private"
    version_control    = "Git"
    work_item_template = "Agile"
}

# Create the AzDO Service Connection
resource "null_resource" "ado_service_connection" {
    depends_on = ["azuredevops_project.ado_project"]

    provisioner "local-exec" {
        command = "./create_service_connection.sh"
        environment = {
            AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY = "${azuread_service_principal_password.sp_password_ado.value}"
            AZDO_ORG_SERVICE_URL                            = "${var.azdo_url}"
            TF_SP_ADO_                                      = "${azuread_service_principal.sp_ado.application_id}"
            TF_SUBSCRIPTION_ID                              = "${data.azurerm_client_config.current.subscription_id}"
            TF_TENANT_ID                                    = "${data.azurerm_client_config.current.tenant_id}"
            TF_APP_NAME                                     = "${var.app_name}"
        }
    }
}