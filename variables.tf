variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "prez_api_app" {
  description = "Configuration for the Prez API container app."
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