# Agent on GCP: BigQuery Data Assistant

A production-ready BigQuery natural language agent built with the **Google Agent Development Kit (ADK)** and deployed natively to **Google Cloud Run** using **Terraform** and **agents-cli**.

This repository serves as a reference architecture demonstrating **dual extension patterns** for both tools and skills:
1. **Managed Tools & Skills**: Leveraging Google Cloud's official managed MCP servers and the Gemini Agent Platform Skill Registry.
2. **Custom Tools & Skills**: Extending the agent with custom Python tools and local organizational skill definitions following the `agentskills.io` standard.

---

## Key Features

- **Dual Tool Pattern**:
  - **Managed MCP Server**: Connects via `McpToolset` to `https://bigquery.googleapis.com/mcp`, natively inheriting Google Cloud's official BigQuery MCP tools (query execution, schema inspection, dataset exploration).
  - **Custom Tool**: Implements `get_current_utc_date()` in Python to resolve relative dates (e.g., "today", "last week") during SQL query generation.
- **Dual Skill Pattern**:
  - **Managed Skill (`bigquery-basics`)**: Integrated via `GCPSkillRegistry` to dynamically retrieve best practices from Google Cloud's regional skill registry (`us`, `eu`, `global`).
  - **Custom Local Skill (`custom-sql-guidelines`)**: Authored in `src/agent/app/skills/custom-sql-guidelines/SKILL.md` to enforce organizational SQL safety rules (mandatory `LIMIT 1000`, partition filtering, and safe casting).
- **Private Cloud Run Service**:
  - Container image generated and built on Cloud Build by `agents-cli` (no committed `Dockerfile`).
  - Disallows unauthenticated access (`allUsers`). Requests require Google-signed OIDC bearer tokens.
- **Infrastructure as Code (Terraform)**:
  - Modular Terraform (`modules/iam`, `modules/cloudrun`, `modules/scheduler`) manages the Service Account, Cloud Run service, and scheduled cron jobs.
  - Cloud Scheduler triggers periodic dataset reports by hitting the Cloud Run `/run` endpoint with an OIDC token generated from the agent's Service Account.

---

## Repository Structure

```text
├── .pre-commit-config.yaml      # Quality, formatting, typing, terraform, and security hooks
├── deploy.sh                    # Hybrid Terraform + agents-cli deployment script
├── destroy.sh                   # Terraform teardown script
├── pyproject.toml               # Python dependencies and tool configurations
├── README.md                    # Project documentation
├── skills/
│   └── quality_standards.md     # Engineering & pre-commit quality standards
├── src/
│   └── agent/                   # agents-cli project root (scaffold artifacts generated here)
│       └── app/                 # Agent package (ADK + agents-cli convention)
│           ├── agent.py         # ADK Agent definition, tools, and skill wiring
│           ├── adapters/
│           │   └── bq_mcp_client.py  # Authenticated managed BigQuery MCP client
│           └── skills/
│               └── custom-sql-guidelines/
│                   └── SKILL.md # Custom organizational SQL guidelines skill
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

# Run all pre-commit linters and type checkers
uv run pre-commit run --all-files
```

---

## Branch Strategy

- **`main` branch**: Focuses on direct CLI deployments (using the native ADK CLI or `agents-cli` auto-scaffolding). It is lightweight and focuses strictly on the agent runtime code.
- **`feature/cloudrun-agent` branch**: Explores a hybrid Infrastructure-as-Code (IaC) pattern. It contains a Terraform-managed Cloud Run deployment pipeline (`terraform apply` + `agents-cli`), allowing the agent infrastructure to be configured further alongside accessory resources (e.g., Cloud Scheduler, private networking, databases).

---

## Deployment & Lifecycle Management

### Option A: Automated Hybrid Deployment (Recommended)

The automated script provisions all infrastructure via Terraform, then builds and deploys the container via `agents-cli`:

```bash
# 1. Authenticate to Google Cloud and set active project
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# 2. Run deployment
./deploy.sh
```

### Option B: Manual Step-by-Step Deployment

1. **Provision infrastructure with Terraform**:
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform apply \
     -var="project_id=YOUR_PROJECT_ID" \
     -var="region=us-central1"
   ```
   *(On the first run, Cloud Run starts with a placeholder image; the image attribute is ignored by Terraform afterwards.)*

2. **Scaffold the serving layer and deploy with agents-cli** (generates the Dockerfile + FastAPI app, builds the container on Cloud Build, and updates the service):
   ```bash
   cd ../../src/agent
   uvx --from google-agents-cli agents-cli scaffold enhance --deployment-target cloud_run --auto-approve
   uvx --from google-agents-cli agents-cli deploy \
     --deployment-target cloud_run \
     --project="YOUR_PROJECT_ID" \
     --region="us-central1" \
     --service-name="$(cd ../../terraform/environments/dev && terraform output -raw cloudrun_service_name)" \
     --service-account="$(cd ../../terraform/environments/dev && terraform output -raw service_account_email)"
   ```
   *(`agents-cli deploy` takes no positional path — it deploys the current directory, so run it from `src/agent/`.)*

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
