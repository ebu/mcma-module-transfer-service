#########################
# Provider registration
#########################

provider "azurerm" {
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  client_id       = var.AZURE_CLIENT_ID
  client_secret   = var.AZURE_CLIENT_SECRET

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "mcma" {
  alias = "azure"

  service_registry_url = module.service_registry_azure.service_url

  mcma_api_key_auth {
    api_key = random_password.deployment_api_key.result
  }
}

######################
# Resource Group
######################

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.prefix}-${var.azure_location}"
  location = var.azure_location
}

######################
# App Storage Account
######################

resource "azurerm_storage_account" "app_storage_account" {
  name                     = format("%.24s", replace("${var.prefix}-${azurerm_resource_group.resource_group.location}", "/[^a-z0-9]+/", ""))
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


######################
# App Service Plan
######################

resource "azurerm_service_plan" "app_service_plan" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

######################
# Cosmos DB
######################

resource "azurerm_cosmosdb_account" "cosmosdb_account" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Strong"
  }

  geo_location {
    failover_priority = 0
    location          = azurerm_resource_group.resource_group.location
  }
}


########################
# Application Insights
########################

resource "azurerm_log_analytics_workspace" "app_insights" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
}

resource "azurerm_application_insights" "app_insights" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  workspace_id        = azurerm_log_analytics_workspace.app_insights.id
  application_type    = "web"
}

#########################
# Service Registry Module
#########################

module "service_registry_azure" {
  source = "https://ch-ebu-mcma-module-repository.s3.eu-central-1.amazonaws.com/ebu/service-registry/azure/0.16.1-beta6/module.zip"

  prefix = "${var.prefix}-service-registry"

  resource_group      = azurerm_resource_group.resource_group
  app_storage_account = azurerm_storage_account.app_storage_account
  app_service_plan    = azurerm_service_plan.app_service_plan
  app_insights        = azurerm_application_insights.app_insights
  cosmosdb_account    = azurerm_cosmosdb_account.cosmosdb_account

  api_keys_read_only = [
    module.job_processor_azure.api_key,
    module.cloud_storage_service_aws.api_key,
  ]

  api_keys_read_write = [
    random_password.deployment_api_key.result
  ]
}

#########################
# Job Processor Module
#########################

module "job_processor_azure" {
  providers = {
    mcma = mcma.azure
  }

  source = "https://ch-ebu-mcma-module-repository.s3.eu-central-1.amazonaws.com/ebu/job-processor/azure/0.16.1-beta3/module.zip"
  prefix = "${var.prefix}-job-processor"

  resource_group      = azurerm_resource_group.resource_group
  app_storage_account = azurerm_storage_account.app_storage_account
  app_service_plan    = azurerm_service_plan.app_service_plan
  app_insights        = azurerm_application_insights.app_insights
  cosmosdb_account    = azurerm_cosmosdb_account.cosmosdb_account

  service_registry = module.service_registry_azure

  api_keys_read_write = [
    random_password.deployment_api_key.result,
    module.cloud_storage_service_aws.api_key,
  ]
}

module "cloud_storage_service_azure" {
  providers = {
    mcma = mcma.azure
  }

  source = "../azure/build/staging"

  prefix = "${var.prefix}-css"

  resource_group      = azurerm_resource_group.resource_group
  app_storage_account = azurerm_storage_account.app_storage_account
  app_service_plan    = azurerm_service_plan.app_service_plan
  app_insights        = azurerm_application_insights.app_insights
  cosmosdb_account    = azurerm_cosmosdb_account.cosmosdb_account

  service_registry = module.service_registry_azure

  api_keys_read_write = [
    random_password.deployment_api_key.result
  ]
}
