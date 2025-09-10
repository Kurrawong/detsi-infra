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

resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-${var.project}-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_dns_zone" "custom_domain" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = var.dns.zone_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_container_app" "app" {
  name                         = "ca-${var.project}-${var.environment}-${var.prez_api_app.name}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Multiple"

  # Ignore changes to template as we'll manage revisions via GitHub Actions
  lifecycle {
    ignore_changes = [
      template
    ]
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = var.prez_api_app.name
      image  = var.prez_api_app.image
      cpu    = var.prez_api_app.cpu
      memory = var.prez_api_app.memory

      env {
        name  = "SPARQL_REPO_TYPE"
        value = "pyoxigraph_persistent"
      }

      env {
        name  = "ENABLE_SPARQL_ENDPOINT"
        value = "true"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/health"
        timeout   = 5
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8000
        path      = "/health"
        timeout   = 3
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

resource "azurerm_dns_cname_record" "prez_api" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = "prez-api"
  zone_name           = azurerm_dns_zone.custom_domain[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_container_app.app.ingress[0].fqdn
}

resource "azurerm_dns_txt_record" "domain_verification" {
  count               = var.dns.zone_name != null ? 1 : 0
  name                = "asuid.prez-api"
  zone_name           = azurerm_dns_zone.custom_domain[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300

  record {
    value = azurerm_container_app.app.custom_domain_verification_id
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