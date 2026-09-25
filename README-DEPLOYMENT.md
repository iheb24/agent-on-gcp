# Deployment Guide

This guide covers the **hybrid deployment**: Terraform provisions the infrastructure (Cloud Run, IAM, Cloud Scheduler), and the Gemini Agent Platform CLI (`agents-cli`) delivers the application (container build on Cloud Build + Cloud Run service update).

## Prerequisites

- Google Cloud CLI (`gcloud`) installed and authenticated.
- Terraform installed (`>= 1.0`).
- [`uv`](https://github.com/astral-sh/uv) installed (used to run `agents-cli` in isolation via `uvx`).
- `terraform/environments/dev/.terraform.lock.hcl` is committed — keep it in version control for reproducible provider versions.

## Deploying

Everything is automated by the root script:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

./deploy.sh
```

The script performs two steps:

1. **Infrastructure Provisioning (Terraform)**
   ```bash
   terraform -chdir=terraform/environments/dev init
   terraform -chdir=terraform/environments/dev apply -auto-approve
   ```
   On the first run, Cloud Run starts with a placeholder image. The `cloudrun` module sets `lifecycle { ignore_changes = [template[0].containers[0].image] }`, so subsequent `terraform apply` runs never overwrite the image deployed by `agents-cli`.

2. **Application Delivery (agents-cli)**
   `agents-cli` analyzes the Python source in `src/agent/`, builds an optimized container on Cloud Build, and updates the Cloud Run service:
   ```bash
   uvx --from google-agents-cli agents-cli deploy src/agent \
     --project="$PROJECT_ID" \
     --region="$REGION" \
     --service-name="$(terraform -chdir=terraform/environments/dev output -raw cloudrun_service_name)" \
     --service-account="$(terraform -chdir=terraform/environments/dev output -raw service_account_email)"
   ```
   `agents-cli` tracks its own state in `deployment_metadata.json` (gitignored). There is **no committed `Dockerfile`** on purpose — the CLI generates the container definition dynamically.

## Tearing Down

```bash
./destroy.sh
```

This removes `deployment_metadata.json` and runs `terraform -chdir=terraform/environments/dev destroy -auto-approve`, deleting the Cloud Run service, Scheduler job, Service Account, and IAM bindings.

## Daily Scheduled Runs

Cloud Scheduler invokes the private service at `POST $SERVICE_URL/run` daily at 09:00 UTC, authenticating with an OIDC token from the agent Service Account (granted `roles/run.invoker`).
