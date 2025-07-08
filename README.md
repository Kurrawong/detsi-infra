# DETSI Infra Code

## Custom Domain Name and SSL Certificate

azurerm does not support managed certificates for container apps. See https://github.com/hashicorp/terraform-provider-azurerm/issues/21866.

In order for the custom domain name to use the managed certificate correctly, you must create the custom domain name manually and select "Managed certificate" for the TLS/SSL certificate option.

There's currently a bug where if the managed certificate is created separately after the custom domain name, it fails to assign.
