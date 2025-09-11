project     = "detsi-prez"
environment = "test"
region      = "Australia East"
prez_api = {
  name                 = "prez-api"
  runtime_version      = "3.12"
  runtime              = "python"
  storage_account_tier = "Standard"
  storage_replication  = "LRS"
}
dns = {
  zone_name = "detsi.dev.kurrawong.ai"
}
github_repository  = "Kurrawong/detsi-vocabs"
github_environment = "production"