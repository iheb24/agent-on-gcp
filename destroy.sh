#!/usr/bin/env bash
# Tear down the hybrid deployment: remove agents-cli state, then destroy all
# Terraform-managed infrastructure.
set -euo pipefail

main() {
    echo "🚨 Starting Teardown of Cloud Run Agent Infrastructure via Terraform..."

    # 1. Ensure GCP project ID is set
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Error: Could not determine GCP project. Run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi

    REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
    TF_DIR="terraform/environments/dev"

    echo "✅ Using Project: $PROJECT_ID"
    echo "✅ Target Region: $REGION"

    # 2. Remove agents-cli deployment state
    echo "🧹 Removing agents-cli deployment metadata..."
    rm -f deployment_metadata.json

    # 3. Destroy Infrastructure via Terraform
    echo "🏗️  Destroying Terraform Infrastructure..."
    terraform -chdir="$TF_DIR" init
    terraform -chdir="$TF_DIR" destroy \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -auto-approve

    echo ""
    echo "✅ Cloud Run Agent infrastructure successfully destroyed!"
}

main "$@"
