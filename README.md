# Agent on GCP: Cloud Run Architecture

A production-ready BigQuery natural language agent built with the **Google Agent Development Kit (ADK)** and deployed to **Google Cloud Run** using **Terraform** and **Docker**.

> **Note on Branch Architecture**:
> This branch (`feature/cloudrun-agent`) showcases the **self-hosted containerized** reference architecture using Cloud Run and Terraform. For the fully managed serverless deployment on Vertex AI Agent Engine, refer to the `main` branch.

---

## Architectural Highlights

- **Dual Tool Pattern**:
  - **Managed MCP Server**: Connects via `McpToolset` to `https://bigquery.googleapis.com/mcp`, natively inheriting Google Cloud's official BigQuery MCP tools (query execution, schema inspection, dataset exploration).
  - **Custom Tool**: Implements `get_current_utc_date()` in Python to resolve relative dates (e.g., "today", "last week") during SQL query generation.
- **Dual Skill Pattern**:
  - **Managed Skill (`bigquery-basics`)**: Integrated via `GCPSkillRegistry` to dynamically retrieve best practices from Google Cloud's regional skill registry (`us`, `eu`, `global`).
  - **Custom Local Skill (`custom-sql-guidelines`)**: Authored in `src/agent/skills/custom-sql-guidelines/SKILL.md` to enforce organizational SQL safety rules (mandatory `LIMIT 1000`, partition filtering, and safe casting).
- **Private Cloud Run Service**:
  - Packaged via a hardened, multi-layer `Dockerfile` running native `adk api_server`.
  - Disallows unauthenticated access (`allUsers`). Requests require Google-signed OIDC bearer tokens.
- **Infrastructure as Code (Terraform)**:
  - Modular Terraform (`modules/iam`, `modules/cloudrun`, `modules/scheduler`) manages the Service Account, Cloud Run service, and scheduled cron jobs.
  - Cloud Scheduler triggers periodic dataset reports by hitting the Cloud Run `/run` endpoint with an OIDC token generated from the agent's Service Account.

---

## Repository Structure

```text
├── .pre-commit-config.yaml      # Quality, formatting, typing, terraform, and security hooks
├── deploy.sh                    # Automated Cloud Build + Terraform deployment script
├── Dockerfile                   # Hardened container image running ADK api_server
├── pyproject.toml               # Python dependencies and tool configurations
├── README.md                    # Project documentation
├── skills/
│   └── quality_standards.md     # Engineering & pre-commit quality standards
├── src/
│   └── agent/
│       ├── agent.py             # ADK Agent definition, tools, and skill wiring
│       └── skills/
│           └── custom-sql-guidelines/
│               └── SKILL.md     # Custom organizational SQL guidelines skill
├── terraform/                   # Infrastructure as Code
│   ├── environments/dev/        # Dev environment entrypoint
│   └── modules/                 # Reusable modules (cloudrun, iam, scheduler)
└── tests/
    └── test_agent.py            # Unit tests for tools and skill configuration
```

---

## Setup & Local Development

### 1. Prerequisites
- Python 3.11+
- [`uv`](https://github.com/astral-sh/uv) package manager
- Google Cloud SDK (`gcloud`)
- [Terraform](https://www.terraform.io/) (>= 1.0)
- [Hadolint](https://github.com/hadolint/hadolint#install) (Official cross-platform Dockerfile linter for Linux, macOS, and Windows)

> **Note on Security Linters**: `checkov` is automatically installed inside the virtual environment via `uv pip install -e ".[dev]"`.

### 2. Environment Setup
```bash
# Create and activate virtual environment
uv venv
source .venv/bin/activate

# Install all dependencies (including dev tools)
uv pip install -e ".[dev]"

# Install pre-commit hooks
pre-commit install --hook-type commit-msg
pre-commit install
```

### 3. Running Tests & Quality Checks
```bash
# Run unit tests
uv run pytest

# Run all pre-commit linters, Docker linters, and type checkers
uv run pre-commit run --all-files
```

---

## Deployment

### Option A: Automated Single-Step Deployment (Recommended)

The automated script builds the container image using Google Cloud Build and provisions all infrastructure via Terraform:

```bash
# 1. Authenticate to Google Cloud and set active project
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# 2. Run deployment
./deploy.sh
```

### Option B: Manual Step-by-Step Deployment

1. **Build and push container image**:
   ```bash
   gcloud builds submit --tag "gcr.io/YOUR_PROJECT_ID/bq-agent-service:latest" .
   ```

2. **Provision infrastructure with Terraform**:
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform apply \
     -var="project_id=YOUR_PROJECT_ID" \
     -var="region=us-central1" \
     -var="image_url=gcr.io/YOUR_PROJECT_ID/bq-agent-service:latest"
   ```

---

## Invoking the Private Cloud Run Agent

Because the Cloud Run service is strictly private, invoke it with an authorized OIDC bearer token:

```bash
SERVICE_URL=$(cd terraform/environments/dev && terraform output -raw cloud_run_service_url)

curl -X POST "$SERVICE_URL/run" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"new_message": {"role": "user", "parts": [{"text": "Show me total dataset usage"}]}}'
```

---

## Teardown

To destroy the Cloud Run service, IAM bindings, and Cloud Scheduler job via Terraform:

```bash
./destroy.sh
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
