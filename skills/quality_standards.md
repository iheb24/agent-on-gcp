---
name: quality-standards
description: Enforce quality standards and pre-commit hooks for the agent-on-gcp repository.
---

# Quality Standards

This repository maintains strict quality standards using `pre-commit`.

## Pre-commit Requirement

Before making any git commits, you MUST ensure that `pre-commit` hooks are installed and run successfully.
To install the hooks, run:
```bash
pre-commit install
```

If you are modifying files, you should run `pre-commit run --all-files` (or on specific files) to fix formatting and linting errors before committing.

## Tools Overview

1. **Python**:
   - We use `uv` for dependency management.
   - We use `black` for formatting and `isort` for import sorting.
   - We use `ruff` for linting.
   - We use `pytest` for unit testing.
   - **ADK Integration**: Ensure that agent logic utilizes the Google Cloud Agent Development Kit (ADK) patterns or `google-genai` agent primitives where applicable.

2. **Terraform**:
   - We use `tflint` for static analysis.
   - We use `checkov` for security scanning.
   - Organize terraform into modules by theme (e.g., `cloudrun`, `iam`, `scheduler`).
   - Network and auth boundaries (e.g., OIDC, Private Cloud Run) MUST be defined in Terraform, even if platform registration happens via CLI.

3. **Security**:
   - `gitleaks` is used to prevent secrets from being committed. Do not bypass gitleaks errors.
