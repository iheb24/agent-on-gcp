#!/usr/bin/env bash
set -e

main() {
    echo "🚀 Starting Deployment to Google Cloud Run with Terraform..."

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
    echo "📦 Target Container: $IMAGE_TAG"

    # 2. Build the container image via Google Cloud Build
    echo "☁️  Building container image via Google Cloud Build..."
    gcloud builds submit --tag "$IMAGE_TAG" . --project="$PROJECT_ID"

    # 3. Provision Infrastructure via Terraform
    echo "🏗️  Applying Terraform Infrastructure..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR/terraform/environments/dev"

    terraform init
    terraform apply \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -var="image_url=$IMAGE_TAG" \
        -auto-approve

    # 4. Extract and display outputs
    SERVICE_URL=$(terraform output -raw cloud_run_service_url)
    AGENT_SA=$(terraform output -raw agent_service_account)

    echo ""
    echo "=========================================================="
    echo "✅ Deployment Successful!"
    echo "=========================================================="
    echo "🌐 Cloud Run Service URL: $SERVICE_URL"
    echo "🔐 Agent Service Account: $AGENT_SA"
    echo "⏰ Cloud Scheduler: Configured to invoke $SERVICE_URL/run daily"
    echo ""
    echo "To test the private service using your active identity:"
    echo "  curl -X POST \"$SERVICE_URL/run\" \\"
    echo "    -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"new_message\": {\"role\": \"user\", \"parts\": [{\"text\": \"Show me total dataset usage\"}]}}'"
    echo "=========================================================="
}

main "$@"
