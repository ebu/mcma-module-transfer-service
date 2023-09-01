data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "service" {
  name                       = format("%.24s", replace("${var.prefix}-${var.resource_group.location}", "/[^a-zA-Z0-9]+/", ""))
  location                   = var.resource_group.location
  resource_group_name        = var.resource_group.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["0.0.0.0/0"]
  }
}

resource "azurerm_key_vault_access_policy" "deployment" {
  key_vault_id       = azurerm_key_vault.service.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = [
    "List",
    "Set",
    "Get",
    "Delete",
    "Purge",
    "Recover"
  ]
}

resource "azurerm_key_vault_access_policy" "api_handler" {
  key_vault_id = azurerm_key_vault.service.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_function_app.api_handler.identity[0].principal_id

  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "worker" {
  key_vault_id = azurerm_key_vault.service.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_function_app.worker.identity[0].principal_id

  secret_permissions = ["Get"]
}

locals {
  api_keys_read_only = {
    for api_key in var.api_keys_read_only :
    api_key => {}
  }
  api_keys_read_write = merge({
    for api_key in var.api_keys_read_write :
    api_key => {
      "^/job-assignments(?:/.+)?$" = ["ANY"]
    }
  })
}

resource "azurerm_key_vault_secret" "api_key_security_config" {
  depends_on = [azurerm_key_vault_access_policy.deployment]

  key_vault_id = azurerm_key_vault.service.id
  name         = "api-key-security-config"
  value        = jsonencode(merge({
    "no-auth"    = {}
    "valid-auth" = {
      "^/job-assignments(?:/.+)?$" = ["GET"]
    }
  },
    local.api_keys_read_only,
    local.api_keys_read_write
  ))
}

resource "azurerm_key_vault_secret" "api_key" {
  depends_on = [azurerm_key_vault_access_policy.deployment]

  key_vault_id = azurerm_key_vault.service.id
  name         = "api-key"
  value        = random_password.api_key.result
}

resource "random_password" "api_key" {
  length  = 32
  special = false
}

locals {
  aws_config = merge({
    for each in var.aws_s3_buckets :
    each.bucket => {
      region    = each.region
      accessKey = each.access_key
      secretKey = each.secret_key
      endpoint  = each.endpoint
    }
  })
  azure_config = merge({
    for each in var.azure_storage_accounts :
    each.account => {
      connectionString = each.connection_string
    }
  })
}

resource "azurerm_key_vault_secret" "storage_client_config" {
  depends_on = [azurerm_key_vault_access_policy.deployment]

  key_vault_id = azurerm_key_vault.service.id
  name         = "storage-client-config"
  value        = jsonencode({
    aws   = local.aws_config
    azure = local.azure_config
  })
}
