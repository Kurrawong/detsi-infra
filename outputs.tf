output "prez_api_app_url" {
  description = "The public URL of the Prez API container app."
  value       = "https://${azurerm_container_app.app.latest_revision_fqdn}"
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
