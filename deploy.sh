#!/usr/bin/env bash
# Hybrid deployment: Terraform owns the infrastructure (Cloud Run service,
# IAM, Cloud Scheduler), agents-cli owns the application delivery (builds the
# container on Cloud Build and updates the Cloud Run service image).
set -euo pipefail

main() {
    echo "🚀 Starting Hybrid Deployment (Terraform + agents-cli)..."

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

    # 2. Provision Infrastructure via Terraform
    #    On the first run this deploys a placeholder image; the image attribute
    #    is ignored afterwards (lifecycle ignore_changes) so agents-cli owns it.
    echo "🏗️  Applying Terraform Infrastructure..."
    terraform -chdir="$TF_DIR" init
    terraform -chdir="$TF_DIR" apply \
        -var="project_id=$PROJECT_ID" \
        -var="region=$REGION" \
        -auto-approve

    SERVICE_NAME=$(terraform -chdir="$TF_DIR" output -raw cloudrun_service_name)
    SERVICE_ACCOUNT=$(terraform -chdir="$TF_DIR" output -raw service_account_email)

    # 3. Scaffold the Cloud Run serving layer (Dockerfile, fast_api_app.py)
    #    agents-cli deploy builds via `gcloud run deploy --source`, which
    #    requires the generated Dockerfile.
    echo "🛠️  Scaffolding Cloud Run deployment artifacts..."
    (cd src/agent && uvx --from google-agents-cli agents-cli scaffold enhance \
        --deployment-target cloud_run \
        --auto-approve)

    # 4. Deploy Application Logic via agents-cli
    #    agents-cli deploy takes no positional path; it deploys the current
    #    project directory, so run it inside src/agent. The cloud_run target
    #    is a thin wrapper over `gcloud run deploy` and writes no state file.
    echo "☁️  Deploying agent to Cloud Run via agents-cli..."
    (cd src/agent && uvx --from google-agents-cli agents-cli deploy \
        --deployment-target cloud_run \
        --project="$PROJECT_ID" \
        --region="$REGION" \
        --service-name="$SERVICE_NAME" \
        --service-account="$SERVICE_ACCOUNT" \
        --no-confirm-project)

    # 5. Extract and display outputs
    SERVICE_URL=$(terraform -chdir="$TF_DIR" output -raw cloud_run_service_url)

    echo ""
    echo "=========================================================="
    echo "✅ Deployment Successful!"
    echo "=========================================================="
    echo "🌐 Cloud Run Service URL: $SERVICE_URL"
    echo "🔐 Agent Service Account: $SERVICE_ACCOUNT"
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
