output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.rg.name
}

output "prez_api_container_app_name" {
  description = "The name of the Prez API container app."
  value       = azurerm_container_app.app.name
}

output "prez_api_app_url" {
  description = "The public URL of the Prez API container app."
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "custom_domain_url" {
  description = "The custom domain URL if configured"
  value       = var.dns.zone_name != null ? "https://prez-api.${var.dns.zone_name}" : null
}

output "dns_zone_name_servers" {
  description = "Name servers for the DNS zone (to configure in your parent domain)"
  value       = var.dns.zone_name != null ? azurerm_dns_zone.custom_domain[0].name_servers : null
}

output "domain_verification_id" {
  description = "Domain verification ID for Container Apps custom domain"
  value       = azurerm_container_app.app.custom_domain_verification_id
  sensitive   = true
}

# GitHub Actions Federated Identity Credentials
output "github_actions_client_id" {
  description = "Client ID for GitHub Actions service principal"
  value       = azuread_application.github_actions.client_id
}

output "github_actions_tenant_id" {
  description = "Tenant ID for GitHub Actions authentication"
  value       = data.azuread_client_config.current.tenant_id
}

output "github_actions_subscription_id" {
  description = "Subscription ID for GitHub Actions authentication"
  value       = data.azurerm_client_config.current.subscription_id
}

output "github_actions_federated_credential_id" {
  description = "ID of the federated identity credential for GitHub Actions"
  value       = azuread_application_federated_identity_credential.github_actions.id
}
