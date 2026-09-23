# Deployment Guide

This guide covers deploying the Agent using the Gemini Agent Platform CLI and Terraform.

## Prerequisites

- Google Cloud CLI (`gcloud`) installed and authenticated.
- Terraform installed.
- Gemini Agent Platform CLI (`gemini`) installed.

## 1. Infrastructure Provisioning

First, provision the infrastructure (Cloud Run, IAM, Cloud Scheduler) using Terraform.

```bash
cd terraform/environments/dev

# Initialize terraform
terraform init

# Provide your project ID (replace YOUR_PROJECT_ID)
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

*Note: Initially, Terraform will deploy a placeholder image. You'll update this once you build your agent container.*

## 2. Deploying with ADK & Gemini Agent Platform CLI

Build the Docker container and push it to Google Artifact Registry:

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev

# Assuming you have an Artifact Registry repo named 'agent-repo'
docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/agent-repo/bq-agent:latest .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/agent-repo/bq-agent:latest
```

Update the Terraform configuration in `terraform/environments/dev/main.tf` to point to the new `image_url`, and run `terraform apply` again.

## 3. Registering the Agent

Once deployed on Cloud Run, use the Gemini Agent Platform CLI to register the agent for monitoring and integration:

```bash
gemini agents create \
  --name "BigQuery Report Agent" \
  --endpoint "https://YOUR_CLOUD_RUN_URL/prompt" \
  --auth-type "OIDC" \
  --service-account "bq-agent-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

You can monitor the agent's usage and interactions on the Gemini Agent Platform dashboard.
