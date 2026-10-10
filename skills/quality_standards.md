---
name: quality-standards
description: Enforce quality standards and pre-commit hooks for the agent-on-gcp repository.
---

# Quality Standards

This repository maintains strict quality standards using `pre-commit` and the Google Agent Development Kit (ADK).

## Pre-commit Requirement

Before any git commit, `pre-commit` hooks must be installed and run successfully.
To install the hooks, run:
```bash
pre-commit install --hook-type commit-msg
pre-commit install
```

Modified files should pass `pre-commit run --all-files` (or a file-scoped run) to fix formatting and linting errors before committing.

## Tools & Standards Overview

1. **Python**:
   - `uv` for dependency management.
   - `black` for formatting and `isort` for import sorting.
   - `ruff` for linting.
   - `mypy` for static type checking.
   - `pytest` for unit testing.
   - `commitizen` to enforce Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`).

2. **Agent Development Kit (ADK) & Agent Platform**:
   - **Agent Engine Hosting**: The agent is designed for native hosting on the managed Gemini Agent Platform (Vertex AI Agent Engine).
   - **Tools Extension**: Follow the dual-tool pattern where applicable (combine Google-managed MCP servers via `McpToolset` with pure Python tools).
   - **Skills Extension**: Adhere to the `agentskills.io` standard (`SKILL.md`) for custom skills, combined with `GCPSkillRegistry` for cloud-managed skills.
   - **Serverless Infrastructure**: No manual hosting infrastructure (such as Cloud Run or GKE) or heavy IaC (Terraform) for the agent runtime.

3. **Security**:
   - `gitleaks` is used to prevent secrets and credentials from being committed. Gitleaks errors must not be bypassed.
