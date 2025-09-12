terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    # Backend configuration will be provided via -backend-config
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.region

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "logs-${var.project}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_dns_zone" "custom_domain" {
  name                = var.dns.zone_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_storage_account" "prez_api" {
  name                     = "st${replace(var.project, "-", "")}${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.prez_api.storage_account_tier
  account_replication_type = var.prez_api.storage_replication

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_storage_container" "prez_api" {
  name               = "sc-${var.project}-${var.environment}-${var.prez_api.name}"
  storage_account_id = azurerm_storage_account.prez_api.id
}

resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_application_insights" "prez_api" {
  name                = "ai-${var.project}-${var.environment}-${var.prez_api.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  application_type    = "web"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_function_app_flex_consumption" "prez_api" {
  name                = "func-${var.project}-${var.environment}-${var.prez_api.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.prez_api.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.prez_api.primary_blob_endpoint}${azurerm_storage_container.prez_api.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.prez_api.primary_access_key
  runtime_version             = var.prez_api.runtime_version
  runtime_name                = "python"
  maximum_instance_count      = 40 # 40 is the minimum
  instance_memory_in_mb       = 2048

  site_config {
    application_insights_key               = azurerm_application_insights.prez_api.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.prez_api.connection_string
    minimum_tls_version                    = "1.2"
  }

  app_settings = {
    "FUNCTION_APP_AUTH_LEVEL" = "ANONYMOUS"
    "ENABLE_SPARQL_ENDPOINT"  = "true"
    "SPARQL_REPO_TYPE"        = "pyoxigraph_persistent"
    "PYOXIGRAPH_DATA_DIR"     = "/tmp/pyoxigraph_data_dir"
  }

  https_only = true

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-resource-id"]
    ]
  }
}

resource "azurerm_service_plan" "prez_api" {
  name                = "plan-${var.project}-${var.environment}-${var.prez_api.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_static_web_app" "prez_ui" {
  name                = "stapp-${var.project}-${var.environment}-prez-ui"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.static_web_app_region
  
  lifecycle {
    ignore_changes = [
      repository_branch,
      repository_url
    ]
  }
}

resource "azurerm_dns_cname_record" "prez_ui" {
  name                = "prez"
  zone_name           = azurerm_dns_zone.custom_domain.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_static_web_app.prez_ui.default_host_name
}

resource "azurerm_static_web_app_custom_domain" "prez_ui" {
  static_web_app_id = azurerm_static_web_app.prez_ui.id
  domain_name       = "prez.${azurerm_dns_zone.custom_domain.name}"
  validation_type   = "cname-delegation"
}

resource "azurerm_dns_cname_record" "prez_api" {
  name                = var.prez_api.domain_name
  zone_name           = azurerm_dns_zone.custom_domain.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_function_app_flex_consumption.prez_api.default_hostname
}

resource "azurerm_dns_txt_record" "prez_api_domain_verification" {
  name                = "asuid.${var.prez_api.domain_name}"
  zone_name           = azurerm_dns_zone.custom_domain.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record {
    value = azurerm_function_app_flex_consumption.prez_api.custom_domain_verification_id
  }
}

resource "azurerm_app_service_custom_hostname_binding" "prez_api" {
  hostname            = "${var.prez_api.domain_name}.${azurerm_dns_zone.custom_domain.name}"
  app_service_name    = azurerm_function_app_flex_consumption.prez_api.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_app_service_managed_certificate" "prez_api" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.prez_api.id
}

resource "azurerm_app_service_certificate_binding" "prez_api" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.prez_api.id
  certificate_id      = azurerm_app_service_managed_certificate.prez_api.id
  ssl_state           = "SniEnabled"
}

data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

resource "azuread_application" "github_actions" {
  display_name = "sp-${var.project}-${var.environment}-github-actions"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id                    = azuread_application.github_actions.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions"
  description    = "GitHub Actions federated identity credential"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:environment:${var.github_environment}"
}

resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}