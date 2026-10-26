#!/usr/bin/env bash
# Deploy the agent to Vertex AI Agent Engine (Agent Runtime) via agents-cli.
# agents-cli manages state itself in src/agent/deployment_metadata.json:
# present -> in-place update, absent -> create. Managed sessions/history
# included; OpenTelemetry export enabled via env var.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd gcloud uv uvx
resolve_project

bash "${SCRIPT_DIR}/setup_iam.sh"

# Start from a pristine tree: leftover artifacts (e.g. a manifest from another
# branch's scaffold) break scaffold enhance. deployment_metadata.json (the
# agents-cli state file) is deliberately preserved.
bash "${SCRIPT_DIR}/clean_scaffold.sh"

log "🛠️  Scaffolding Agent Runtime deployment artifacts..."
(cd "${SCRIPT_DIR}/../src/agent" && uvx --from google-agents-cli agents-cli scaffold enhance \
    --deployment-target agent_runtime \
    --auto-approve)
align_scaffold_adk "${SCRIPT_DIR}/../src/agent"

log "☁️  Deploying to Agent Runtime via agents-cli..."
(cd "${SCRIPT_DIR}/../src/agent" && uvx --from google-agents-cli agents-cli deploy \
    --deployment-target agent_runtime \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --service-name="BigQuery Data Assistant" \
    --service-account="$SA_EMAIL" \
    --update-env-vars="GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY=true" \
    --no-confirm-project)

log "✅ Deployment complete! Check 'Agent Platform > Deployments' in the GCP Console."
