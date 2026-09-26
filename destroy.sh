#!/usr/bin/env bash
# Tear down the hybrid deployment: remove agents-cli state, clean scaffold
# artifacts, then destroy all terraform-managed infrastructure.
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

rm -f deployment_metadata.json
bash scripts/clean_scaffold.sh

echo "🏗️  Destroying Terraform Infrastructure..."
terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" destroy \
    -var="project_id=$PROJECT_ID" \
    -var="region=$REGION" \
    -auto-approve

echo "✅ Cloud Run Agent infrastructure successfully destroyed!"
