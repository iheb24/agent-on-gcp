#!/usr/bin/env bash
set -e

main() {
    echo "🚨 Starting Teardown of Cloud Run Agent Infrastructure via Terraform..."

    # 1. Ensure GCP project ID is set
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Error: Could not determine GCP project. Run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi

    REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
    IMAGE_TAG="gcr.io/${PROJECT_ID}/bq-agent-service:latest"

    echo "✅ Using Project: $PROJECT_ID"
    echo "✅ Target Region: $REGION"

    # 2. Destroy Infrastructure via Terraform
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR/terraform/environments/dev"

    echo "🏗️  Destroying Terraform Infrastructure..."
    terraform init
    terraform destroy \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -var="image_url=$IMAGE_TAG" \
        -auto-approve

    echo ""
    echo "✅ Cloud Run Agent infrastructure successfully destroyed!"
}

# Execute main at the very end
main "$@"
