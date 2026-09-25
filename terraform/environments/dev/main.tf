terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  description = "The GCP region"
  default     = "us-central1"
}

variable "image_url" {
  type        = string
  description = "The container image URL to deploy on Cloud Run"
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
  agent_name = "bq-agent"
}

module "cloudrun" {
  source                = "../../modules/cloudrun"
  project_id            = var.project_id
  region                = var.region
  service_name          = "bq-agent-service"
  image_url             = var.image_url
  service_account_email = module.iam.agent_service_account_email
}

module "scheduler" {
  source     = "../../modules/scheduler"
  project_id = var.project_id
  region     = var.region
  job_name   = "daily-report-job"
  schedule   = "0 9 * * *" # Daily at 9am UTC
  target_uri = "${module.cloudrun.service_url}/run"
  message_body = jsonencode({
    user_id    = "cron_scheduler",
    session_id = "cron_daily_run",
    new_message = {
      role  = "user",
      parts = [{ text = "Generate the daily summary report of dataset usage. (Assuming a known schema)" }]
    }
  })
  invoker_sa_email = module.iam.agent_service_account_email
}

# Allow the scheduler service account to invoke Cloud Run
resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  project  = module.cloudrun.project_id
  location = module.cloudrun.region
  name     = module.cloudrun.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.iam.agent_service_account_email}"
}

output "cloud_run_service_url" {
  description = "URL of the deployed private Cloud Run service"
  value       = module.cloudrun.service_url
}

output "agent_service_account" {
  description = "Email of the provisioned agent Service Account"
  value       = module.iam.agent_service_account_email
}

output "cloudrun_service_name" {
  description = "Name of the Cloud Run service (used by agents-cli deploy)"
  value       = module.cloudrun.service_name
}

output "service_account_email" {
  description = "Email of the agent Service Account (used by agents-cli deploy)"
  value       = module.iam.agent_service_account_email
}
