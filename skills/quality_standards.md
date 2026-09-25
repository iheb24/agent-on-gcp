---
name: quality-standards
description: Enforce quality standards and pre-commit hooks for the agent-on-gcp repository (Cloud Run edition).
---

# Quality Standards (Cloud Run Reference Architecture)

This repository maintains strict engineering and security standards using `pre-commit`, `uv`, `terraform`, and `hadolint`.

## Pre-commit Requirement

Before making any git commits, you MUST ensure that `pre-commit` hooks are installed and run successfully.
To install the hooks, run:
```bash
pre-commit install --hook-type commit-msg
pre-commit install
```

To run all quality checks locally:
```bash
uv run pre-commit run --all-files
```

## Tools & Standards Overview

1. **Python**:
   - We use `uv` for dependency management.
   - We use `black` for formatting and `isort` for import sorting.
   - We use `ruff` for linting.
   - We use `mypy` for static type checking.
   - We use `pytest` for unit testing.
   - We use `commitizen` to enforce Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`).

2. **Containerization & Docker**:
   - We use `hadolint` to enforce Dockerfile best practices (pinning base images, avoiding root execution, minimizing layers).
   - The container must run as a non-privileged user (`appuser`).
   - The container must use native `adk api_server` as the entrypoint.

3. **Infrastructure as Code (Terraform)**:
   - We use `terraform_fmt` for formatting.
   - We use `tflint` for static analysis.
   - We use `checkov` for security compliance scanning.
   - Organize terraform into modules by theme (`cloudrun`, `iam`, `scheduler`).
   - Private Cloud Run with OIDC authentication boundaries MUST be preserved (do not grant unauthenticated `allUsers` access).

4. **Security**:
   - `gitleaks` is used to prevent secrets and credentials from being committed. Do not bypass gitleaks errors.
