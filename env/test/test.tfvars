project     = "detsi-prez"
environment = "test"
region      = "Australia East"
# prez_api_app = {
#   name   = "prez-api"
#   image  = "ghcr.io/kurrawong/detsi-prez:0.1.5"
#   cpu    = "1"
#   memory = "2Gi"
# }
prez_api = {
  name                 = "prez-api"
  runtime_version      = "~4"
  runtime              = "python"
  storage_account_tier = "Standard"
  storage_replication  = "LRS"
}
dns = {
  zone_name = "detsi.dev.kurrawong.ai"
}
github_repository  = "Kurrawong/detsi-vocabs"
github_environment = "production"