#!/usr/bin/env bash
# Deploy the agent to a new Cloud Run service (bq-agent-auto) via agents-cli.
# agents-cli scaffolds the Dockerfile and wraps `gcloud run deploy --source`,
# which upserts by service name: re-runs add a revision, never a new service.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd gcloud uv uvx
resolve_project

SERVICE_NAME="bq-agent-auto"
readonly SERVICE_NAME

bash "${SCRIPT_DIR}/setup_iam.sh"

# Start from a pristine tree: leftover artifacts (e.g. a manifest from another
# branch's scaffold) break scaffold enhance.
bash "${SCRIPT_DIR}/clean_scaffold.sh"

log "🛠️  Scaffolding Cloud Run deployment artifacts..."
(cd "${SCRIPT_DIR}/../src/agent" && uvx --from google-agents-cli agents-cli scaffold enhance \
    --deployment-target cloud_run \
    --auto-approve)
align_scaffold_adk "${SCRIPT_DIR}/../src/agent"

log "☁️  Deploying to Cloud Run via agents-cli..."
(cd "${SCRIPT_DIR}/../src/agent" && uvx --from google-agents-cli agents-cli deploy \
    --deployment-target cloud_run \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --service-name="$SERVICE_NAME" \
    --service-account="$SA_EMAIL" \
    --no-confirm-project)

log "✅ Deployment complete! Service: $SERVICE_NAME"
