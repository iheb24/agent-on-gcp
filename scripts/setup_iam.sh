#!/usr/bin/env bash
# Idempotent identity layer for all deployment strategies: service account
# bq-agent-sa plus the IAM roles every target needs. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd gcloud
resolve_project

ROLES=(
    "roles/bigquery.dataViewer"
    "roles/bigquery.jobUser"
    "roles/aiplatform.user"
    "roles/mcp.toolUser"
    "roles/cloudtrace.agent"
    "roles/monitoring.metricWriter"
    "roles/logging.logWriter"
)

log "🔐 Checking Identity Layer (Service Account)..."
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "   Creating Service Account: bq-agent-sa..."
    gcloud iam service-accounts create bq-agent-sa \
        --display-name="BigQuery Agent Service Account" \
        --project="$PROJECT_ID"
    log "   Waiting for IAM principal propagation..."
    sleep 5
else
    log "   Service Account already exists: $SA_EMAIL"
fi

log "🔑 Granting IAM roles to $SA_EMAIL..."
for role in "${ROLES[@]}"; do
    for attempt in {1..5}; do
        if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --project="$PROJECT_ID" >/dev/null 2>&1; then
            log "   ✅ Assigned $role"
            break
        fi
        # IAM principal propagation is eventually consistent; retry.
        if [ "$attempt" -eq 5 ]; then
            die "Failed to assign $role after 5 attempts."
        fi
        log "   ⏳ Principal propagating, retrying $role (attempt $attempt/5)..."
        sleep 4
    done
done

log "✅ Identity Layer provisioned."
