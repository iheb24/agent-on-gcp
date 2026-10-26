#!/usr/bin/env bash
# Shared helpers for the deployment scripts. Source me, don't execute me.

log() { echo "$@"; }

die() {
    echo "❌ $*" >&2
    exit 1
}

require_cmd() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed."
    done
}

# Sets PROJECT_ID, REGION and SA_EMAIL. No-op if already resolved (e.g. the
# caller resolved before invoking another script that also resolves).
resolve_project() {
    [ -z "${PROJECT_ID:-}" ] || return 0
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    [ -n "${PROJECT_ID:-}" ] || die "Could not determine GCP project. Run 'gcloud config set project YOUR_PROJECT_ID'"
    REGION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
    SA_EMAIL="bq-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    # Exported so child scripts (setup_iam.sh) see them and skip re-resolving.
    export PROJECT_ID REGION SA_EMAIL
    log "✅ Using Project: $PROJECT_ID"
    log "✅ Target Region: $REGION"
}

# The agents-cli base template pins google-adk to >=2.8.0,<2.9.0 without the
# mcp extra, but our agent code requires >=2.10 and the mcp package (without
# it, google.adk.tools.mcp_tool doesn't export McpToolset). Repin and relock
# after every scaffold; the generated project is disposable.
# $1 = scaffolded project directory (src/agent)
align_scaffold_adk() {
    local project_dir="$1"
    sed \
        -e 's/google-adk\[bigquery-analytics,gcp,otel-gcp\]>=2\.8\.0,<2\.9\.0/google-adk[bigquery-analytics,gcp,mcp,otel-gcp]>=2.10.0/' \
        -e 's/google-adk\[eval\]>=2\.8\.0,<2\.9\.0/google-adk[eval]>=2.10.0/' \
        "$project_dir/pyproject.toml" > "$project_dir/pyproject.toml.tmp"
    mv "$project_dir/pyproject.toml.tmp" "$project_dir/pyproject.toml"
    (cd "$project_dir" && uv lock --quiet)
}
