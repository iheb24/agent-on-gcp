#!/usr/bin/env bash
# Tear down the auto-scaffolded Cloud Run deployment (bq-agent-auto) created
# by deploy_auto_cloudrun.sh, then clean all scaffold artifacts so the tree
# returns to its pristine state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd gcloud
resolve_project

SERVICE_NAME="bq-agent-auto"
readonly SERVICE_NAME

if gcloud run services describe "$SERVICE_NAME" --project="$PROJECT_ID" --region="$REGION" >/dev/null 2>&1; then
    log "🗑️  Deleting Cloud Run service: $SERVICE_NAME..."
    gcloud run services delete "$SERVICE_NAME" \
        --project="$PROJECT_ID" --region="$REGION" --quiet
    log "   ✅ Deleted $SERVICE_NAME"
else
    log "ℹ️  Cloud Run service $SERVICE_NAME not found. Skipping."
fi

rm -f "${SCRIPT_DIR}/../deployment_metadata.json"
bash "${SCRIPT_DIR}/clean_scaffold.sh"

log "✅ Teardown complete!"
log "ℹ️  The Service Account and IAM bindings are shared; remove them via scripts/destroy_agent_runtime.sh --all if no longer needed."
