terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
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

provider "azuread" {
  # Configuration options
}

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

# resource "azurerm_container_app_environment" "cae" {
#   name                       = "cae-${var.project}-${var.environment}"
#   location                   = azurerm_resource_group.rg.location
#   resource_group_name        = azurerm_resource_group.rg.name
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
# }

resource "azurerm_dns_zone" "custom_domain" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = var.dns.zone_name
  resource_group_name = azurerm_resource_group.rg.name
}

# resource "azurerm_container_app" "app" {
#   name                         = "ca-${var.project}-${var.environment}-${var.prez_api_app.name}"
#   container_app_environment_id = azurerm_container_app_environment.cae.id
#   resource_group_name          = azurerm_resource_group.rg.name
#   revision_mode                = "Multiple"

#   # Ignore changes to template as we'll manage revisions via GitHub Actions
#   lifecycle {
#     ignore_changes = [
#       template
#     ]
#   }

#   template {
#     min_replicas = 0
#     max_replicas = 2

#     container {
#       name   = var.prez_api_app.name
#       image  = var.prez_api_app.image
#       cpu    = var.prez_api_app.cpu
#       memory = var.prez_api_app.memory

#       env {
#         name  = "SPARQL_REPO_TYPE"
#         value = "pyoxigraph_persistent"
#       }

#       env {
#         name  = "ENABLE_SPARQL_ENDPOINT"
#         value = "true"
#       }

#       liveness_probe {
#         transport = "HTTP"
#         port      = 8000
#         path      = "/health"
#         timeout   = 5
#       }

#       readiness_probe {
#         transport = "HTTP"
#         port      = 8000
#         path      = "/health"
#         timeout   = 3
#       }
#     }
#   }

#   ingress {
#     external_enabled = true
#     target_port      = 8000
#     transport        = "http"

#     traffic_weight {
#       percentage      = 100
#       latest_revision = true
#     }
#   }
# }

# resource "azurerm_dns_cname_record" "prez_api" {
#   count               = var.dns.zone_name != null ? 1 : 0
#   name                = "prez-api"
#   zone_name           = azurerm_dns_zone.custom_domain[0].name
#   resource_group_name = azurerm_resource_group.rg.name
#   ttl                 = 300
#   record              = azurerm_container_app.app.ingress[0].fqdn
# }

# resource "azurerm_dns_txt_record" "domain_verification" {
#   count               = var.dns.zone_name != null ? 1 : 0
#   name                = "asuid.prez-api"
#   zone_name           = azurerm_dns_zone.custom_domain[0].name
#   resource_group_name = azurerm_resource_group.rg.name
#   ttl                 = 300

#   record {
#     value = azurerm_container_app.app.custom_domain_verification_id
#   }
# }

# Storage Account for Function App
resource "azurerm_storage_account" "function_app" {
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

resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Application Insights for Function App
resource "azurerm_application_insights" "function_app" {
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

# Function App with Flex Consumption plan
resource "azurerm_linux_function_app" "prez_api" {
  name                = "func-${var.project}-${var.environment}-${var.prez_api.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.function_app.name
  storage_account_access_key = azurerm_storage_account.function_app.primary_access_key
  service_plan_id            = azurerm_service_plan.function_app.id

  site_config {
    application_insights_key               = azurerm_application_insights.function_app.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.function_app.connection_string
    application_stack {
      python_version = var.prez_api.runtime_version
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = var.prez_api.runtime
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "ENABLE_SPARQL_ENDPOINT"   = "true"
    "SPARQL_REPO_TYPE"         = "pyoxigraph_persistent"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# App Service Plan for Function App (Flex Consumption)
resource "azurerm_service_plan" "function_app" {
  name                = "plan-${var.project}-${var.environment}-${var.prez_api.name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1" # Flex Consumption plan

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
}

resource "azurerm_dns_cname_record" "prez_ui" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = "prez"
  zone_name           = azurerm_dns_zone.custom_domain[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_static_web_app.prez_ui.default_host_name
}

resource "azurerm_static_web_app_custom_domain" "prez_ui" {
  count             = var.dns.zone_name != null ? 1 : 0
  static_web_app_id = azurerm_static_web_app.prez_ui.id
  domain_name       = "prez.${azurerm_dns_zone.custom_domain[0].name}"
  validation_type   = "cname-delegation"
}

# DNS CNAME record for Function App
resource "azurerm_dns_cname_record" "prez_api" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = "prez-api"
  zone_name           = azurerm_dns_zone.custom_domain[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_linux_function_app.prez_api.default_hostname
}

# Custom domain for Function App
resource "azurerm_app_service_custom_hostname_binding" "prez_api" {
  count               = var.dns.zone_name != null ? 1 : 0
  hostname            = "prez-api.${azurerm_dns_zone.custom_domain[0].name}"
  app_service_name    = azurerm_linux_function_app.prez_api.name
  resource_group_name = azurerm_resource_group.rg.name
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