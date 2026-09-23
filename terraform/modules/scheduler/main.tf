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

variable "job_name" {
  type        = string
  description = "Name of the scheduler job"
}

variable "schedule" {
  type        = string
  description = "Cron schedule (e.g. '0 9 * * *')"
}

variable "target_uri" {
  type        = string
  description = "Cloud Run service URI to invoke (e.g., /cron/report)"
}

variable "invoker_sa_email" {
  type        = string
  description = "Service account used by Cloud Scheduler to invoke Cloud Run"
}

resource "google_cloud_scheduler_job" "cron_report" {
  name        = var.job_name
  project     = var.project_id
  region      = var.region
  description = "Trigger scheduled report generation on Agent"
  schedule    = var.schedule
  time_zone   = "UTC"

  http_target {
    http_method = "POST"
    uri         = var.target_uri
    body        = base64encode(var.message_body)

    headers = {
      "Content-Type" = "application/json"
    }

    # OIDC authentication to invoke private Cloud Run
    oidc_token {
      service_account_email = var.invoker_sa_email
      audience              = var.target_uri
    }
  }
}

variable "message_body" {
  type        = string
  description = "The HTTP body to send in the request"
  default     = "{}"
}
