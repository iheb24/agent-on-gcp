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

    # 2. Remove agents-cli deployment state and ALL scaffold-generated
    #    artifacts (agents-cli has no 'scaffold clean' command), so the tree
    #    returns to its pristine state.
    echo "🧹 Removing agents-cli deployment metadata and scaffolded artifacts..."
    rm -f deployment_metadata.json
    rm -f src/agent/Dockerfile
    rm -f src/agent/agents-cli-manifest.yaml
    rm -f src/agent/pyproject.toml
    rm -f src/agent/uv.lock
    rm -f src/agent/README.md
    rm -f src/agent/GEMINI.md
    rm -f src/agent/.env
    rm -f src/agent/.gcloudignore
    rm -f src/agent/.gitignore
    rm -rf src/agent/deployment
    rm -rf src/agent/tests
    rm -rf src/agent/.venv
    rm -f src/agent/app/fast_api_app.py
    rm -rf src/agent/app/app_utils
    rm -rf src/agent/app/__pycache__

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
