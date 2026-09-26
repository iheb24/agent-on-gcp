#!/usr/bin/env bash
# Hybrid deploy: terraform provisions infrastructure (Cloud Run, IAM,
# Scheduler), then agents-cli delivers the application (scaffold + build on
# Cloud Build + service update). Cloud Run upserts by service name, so
# re-runs update the same service. The container image is owned by
# agents-cli (terraform ignores it via lifecycle ignore_changes).
set -euo pipefail

TF_DIR="terraform/environments/dev"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: Could not determine GCP project. Run 'gcloud config set project YOUR_PROJECT_ID'" >&2
    exit 1
fi
REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
readonly PROJECT_ID REGION TF_DIR

echo "✅ Using Project: $PROJECT_ID"
echo "✅ Target Region: $REGION"

echo "🏗️  Applying Terraform Infrastructure..."
terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" apply \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -auto-approve

SERVICE_NAME=$(terraform -chdir="$TF_DIR" output -raw cloudrun_service_name)
SERVICE_ACCOUNT=$(terraform -chdir="$TF_DIR" output -raw service_account_email)
readonly SERVICE_NAME SERVICE_ACCOUNT

echo "🛠️  Scaffolding Cloud Run deployment artifacts..."
(cd src/agent && uvx --from google-agents-cli agents-cli scaffold enhance \
    --deployment-target cloud_run \
    --auto-approve)

# The agents-cli base template pins google-adk to >=2.8.0,<2.9.0, but the
# agent code requires >=2.10; repin and relock (generated project is disposable).
sed 's/>=2\.8\.0,<2\.9\.0/>=2.10.0/g' src/agent/pyproject.toml > src/agent/pyproject.toml.tmp
mv src/agent/pyproject.toml.tmp src/agent/pyproject.toml
(cd src/agent && uv lock --quiet)

echo "☁️  Deploying agent to Cloud Run via agents-cli..."
(cd src/agent && uvx --from google-agents-cli agents-cli deploy \
    --deployment-target cloud_run \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --service-name="$SERVICE_NAME" \
    --service-account="$SERVICE_ACCOUNT" \
    --no-confirm-project)

SERVICE_URL=$(terraform -chdir="$TF_DIR" output -raw cloud_run_service_url)

cat <<EOF
==========================================================
✅ Deployment Successful!
==========================================================
🌐 Cloud Run Service URL: $SERVICE_URL
🔐 Agent Service Account: $SERVICE_ACCOUNT
⏰ Cloud Scheduler: invokes $SERVICE_URL/run daily

To test the private service using your active identity:
  curl -X POST "$SERVICE_URL/run" \\
    -H "Authorization: Bearer \$(gcloud auth print-identity-token)" \\
    -H "Content-Type: application/json" \\
    -d '{"new_message": {"role": "user", "parts": [{"text": "Show me total dataset usage"}]}}'
==========================================================
EOF
