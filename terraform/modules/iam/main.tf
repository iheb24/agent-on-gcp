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

variable "agent_name" {
  type        = string
  description = "Name of the agent, used for service account naming"
}

# Service Account for the Agent (Cloud Run Identity)
resource "google_service_account" "agent_sa" {
  account_id   = "${var.agent_name}-sa"
  display_name = "Service Account for ${var.agent_name}"
  project      = var.project_id
}

# Grant BigQuery Data Viewer and Job User to the Agent SA
resource "google_project_iam_member" "bq_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# Grant Vertex AI User so the agent can call Gemini models
resource "google_project_iam_member" "aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# Grant telemetry export roles (traces, metrics, logs) for Cloud Operations
resource "google_project_iam_member" "telemetry" {
  for_each = toset([
    "roles/cloudtrace.agent",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

output "agent_service_account_email" {
  value = google_service_account.agent_sa.email
}
