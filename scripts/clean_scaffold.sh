#!/usr/bin/env bash
# Remove every agents-cli scaffold artifact from src/agent, returning the
# tree to its pristine state (agents-cli has no 'scaffold clean' command).
# Keeps your source (app/agent.py, app/adapters, app/skills) and the tracked
# .env.example template. Safe to run standalone before switching strategies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

rm -f "$REPO_ROOT"/src/agent/Dockerfile
rm -f "$REPO_ROOT"/src/agent/agents-cli-manifest.yaml
rm -f "$REPO_ROOT"/src/agent/pyproject.toml
rm -f "$REPO_ROOT"/src/agent/uv.lock
rm -f "$REPO_ROOT"/src/agent/README.md
rm -f "$REPO_ROOT"/src/agent/GEMINI.md
rm -f "$REPO_ROOT"/src/agent/.env
rm -f "$REPO_ROOT"/src/agent/.gcloudignore
rm -f "$REPO_ROOT"/src/agent/.gitignore
rm -rf "$REPO_ROOT"/src/agent/deployment
rm -rf "$REPO_ROOT"/src/agent/tests
rm -rf "$REPO_ROOT"/src/agent/.venv
rm -f "$REPO_ROOT"/src/agent/app/fast_api_app.py
rm -rf "$REPO_ROOT"/src/agent/app/app_utils
rm -rf "$REPO_ROOT"/src/agent/app/__pycache__

echo "🧹 Scaffold artifacts removed; tree is back to its pre-scaffold state."
