#!/usr/bin/env bash
# Tear down the Agent Runtime deployment recorded in
# src/agent/deployment_metadata.json (agents-cli state file).
# Usage: destroy_agent_runtime.sh [--all]
#   --all also removes the IAM bindings and the service account.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

DELETE_IAM=false
case "${1:-}" in
    --all) DELETE_IAM=true ;;
    "") ;;
    --help|-h)
        echo "Usage: $0 [--all]"
        exit 0
        ;;
    *) die "Unknown option: $1 (use --help)" ;;
esac
readonly DELETE_IAM

require_cmd gcloud jq curl
resolve_project

METADATA_FILE="${REPO_ROOT}/src/agent/deployment_metadata.json"

if [ -f "$METADATA_FILE" ]; then
    RESOURCE_NAME=$(jq -r '.remote_agent_runtime_id // empty' "$METADATA_FILE")
    AGENT_ID="${RESOURCE_NAME##*/}"
    if [ -n "$AGENT_ID" ]; then
        # gcloud has no reasoning-engine command; delete via the REST API.
        log "🗑️  Deleting Agent Runtime instance: $AGENT_ID..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
            -H "Authorization: Bearer $(gcloud auth print-access-token)" \
            "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT_ID}/locations/${REGION}/reasoningEngines/${AGENT_ID}")
        if [ "$HTTP_CODE" = "200" ]; then
            log "   ✅ Deleted $AGENT_ID"
        elif [ "$HTTP_CODE" = "404" ]; then
            log "   ℹ️  Instance $AGENT_ID already gone."
        else
            die "Delete failed with HTTP $HTTP_CODE for $AGENT_ID"
        fi
    else
        log "⚠️  No remote_agent_runtime_id in $METADATA_FILE; skipping remote delete."
    fi
    rm -f "$METADATA_FILE"
else
    log "ℹ️  No deployment_metadata.json found; skipping remote delete."
fi

if [ "$DELETE_IAM" = true ]; then
    log "🔐 Deleting IAM bindings and Service Account..."
    for role in \
        roles/bigquery.dataViewer roles/bigquery.jobUser roles/aiplatform.user \
        roles/mcp.toolUser roles/cloudtrace.agent roles/monitoring.metricWriter roles/logging.logWriter; do
        if gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --project="$PROJECT_ID" >/dev/null 2>&1; then
            log "   ✅ Removed $role binding"
        fi
    done
    if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
        gcloud iam service-accounts delete "$SA_EMAIL" --project="$PROJECT_ID" --quiet
        log "   ✅ Deleted Service Account: $SA_EMAIL"
    fi
else
    log "ℹ️  Service Account $SA_EMAIL preserved (use --all to delete IAM resources)."
fi

bash "${SCRIPT_DIR}/clean_scaffold.sh"

log "✅ Teardown complete!"
