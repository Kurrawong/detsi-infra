variable "project" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "dns" {
  type = object({
    zone_name = string
  })
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo-name'"
  type        = string
}

variable "github_environment" {
  description = "GitHub environment"
  type        = string
}

variable "static_web_app_region" {
  description = "The Azure region for the Static Web App. Static Web Apps are not available in all regions."
  type        = string
  default     = "eastasia"
}

variable "prez_api" {
  description = "Function App configuration"
  type = object({
    name                 = string
    runtime_version      = string
    runtime              = string
    storage_account_tier = string
    storage_replication  = string
    domain_name          = string
  })
}