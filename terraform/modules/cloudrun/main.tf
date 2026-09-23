terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name"
}

variable "image_url" {
  type        = string
  description = "Container image URL"
}

variable "service_account_email" {
  type        = string
  description = "The email of the service account the Cloud Run service will use"
}

resource "google_cloud_run_v2_service" "agent_service" {
  name     = var.service_name
  location = var.region
  project  = var.project_id

  template {
    service_account = var.service_account_email

    containers {
      image = var.image_url

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.region
      }
    }
  }

  # Ensure it is private (no unauthenticated invoker role granted by default)
}

output "service_url" {
  value = google_cloud_run_v2_service.agent_service.uri
}
