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

variable "prez_api_app" {
  description = "Prez API application configuration"
  type = object({
    name   = string
    image  = string
    cpu    = string
    memory = string
  })
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