# Agent on GCP

This repository contains a BigQuery natural language agent deployed on Google Cloud Platform using Cloud Run and the Gemini Agent Platform.

The agent uses the official GCP BigQuery Model Context Protocol (MCP) server to query data using natural language, and it can also generate scheduled reports via a cron job.

## Features

- **BigQuery MCP Integration:** Natural language querying of BigQuery datasets.
- **Scheduled Reports:** Cron job integration to trigger periodic reporting.
- **Secure by Default:** Deployed on private Cloud Run with IAM authentication.
- **Quality Standards:** Uses `uv`, `pre-commit`, `checkov`, `tflint`, `gitleaks`, `black`, `isort`, and `ruff` for code quality and security.

## Setup

1. Make sure you have [`uv`](https://github.com/astral-sh/uv) installed.
2. Create and activate a virtual environment, then install dependencies:
   ```bash
   uv venv
   source .venv/bin/activate
   uv pip install -e ".[dev]"
   ```
3. Install pre-commit hooks:
   ```bash
   pre-commit install
   ```

## Architecture

- **`src/agent/agent.py`**: The pure Google Agent Development Kit (ADK) agent definition, routing, and tool logic.
- **`src/agent/adapters/`**: External API integrations (BigQuery MCP connection).
- **`terraform/`**: Infrastructure as Code (Cloud Run, IAM, Cloud Scheduler).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
