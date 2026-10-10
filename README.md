# Agent on GCP: BigQuery Data Assistant

A BigQuery natural language agent built with the **Google Agent Development Kit (ADK)**, plus a tiered evaluation harness (ADK evals) covering single-turn, multi-turn, and cost-bounded smoke runs.

This repository serves as a reference architecture demonstrating **dual extension patterns** for both tools and skills:
1. **Managed Tools & Skills**: Leveraging Google Cloud's official managed MCP servers and the Gemini Agent Platform Skill Registry.
2. **Custom Tools & Skills**: Extending the agent with custom Python tools and local organizational skill definitions following the `agentskills.io` standard.

---

## Key Features

- **Dual Tool Pattern**:
  - **Managed MCP Server**: Connects via `McpToolset` to `https://bigquery.googleapis.com/mcp`, filtered to the query/metadata tools the agent uses (`BQ_MCP_TOOL_ALLOWLIST`).
  - **Custom Tool**: Implements `get_current_utc_date()` in Python to resolve relative dates (e.g., "today", "last week") during SQL query generation.
- **Dual Skill Pattern**:
  - **Managed Skill (`bigquery-basics`)**: Integrated via `GCPSkillRegistry` to dynamically retrieve best practices from Google Cloud's regional skill registry (`us`, `eu`, `global`).
  - **Custom Local Skill (`custom-sql-guidelines`)**: Authored in `src/agent/app/skills/custom-sql-guidelines/SKILL.md` to enforce organizational SQL safety rules (mandatory `LIMIT 1000`, partition filtering, and safe casting).
- **Tiered ADK Evaluation Harness**: Deterministic trajectory checks, LLM-judged criteria, and scenario-based multi-turn evaluation under `tests/evals/`, with archived baselines and a written evaluation report.
- **Cost-Optimized Prompt Footprint**: MCP tool allowlisting and context caching keep per-call prompt size small and stable.
- **Strict Quality Standards**: Enforced via `uv`, `pre-commit`, `black`, `isort`, `ruff`, `mypy`, and `commitizen` (Conventional Commits).

---

## Repository Structure

```text
├── .pre-commit-config.yaml      # Quality, formatting, typing, and security hooks
├── pyproject.toml               # Python dependencies and tool configurations
├── README.md                    # Project documentation
├── skills/
│   └── quality_standards.md     # Engineering & pre-commit quality standards
├── src/
│   └── agent/
│       ├── .env.example         # Environment variable template
│       └── app/                 # Agent package (ADK convention)
│           ├── agent.py         # ADK Agent definition, tools, and skill wiring
│           ├── adapters/
│           │   └── bq_mcp_client.py  # Authenticated, tool-filtered BigQuery MCP client
│           └── skills/
│               └── custom-sql-guidelines/
│                   └── SKILL.md # Custom organizational SQL guidelines skill
└── tests/
    ├── test_agent.py            # Unit tests for tools and skill configuration
    ├── test_eval.py             # Tiered, gated ADK eval runner (offline by default)
    └── evals/
        ├── bq_agent.evalset.json        # Single-turn core cases
        ├── test_config.json             # Criteria & thresholds (gate tier)
        ├── EVALUATION_REPORT.md         # Baselines, failures, calibration decisions
        ├── baselines/                   # Archived per-run results
        ├── smoke/                       # Tier 1: trajectory-only smoke evalset + config
        └── multiturn/                   # Tier 3: scenario evalsets + config (user simulation)
```

---

## Setup & Local Development

### 1. Prerequisites
- Python 3.11+
- [`uv`](https://github.com/astral-sh/uv) package manager
- Google Cloud SDK (`gcloud`) with application-default credentials

### 2. Environment Setup
```bash
# Sync all dependencies (including dev tools) into virtualenv using uv
uv sync --extra dev

# Install pre-commit hooks
uv run pre-commit install --hook-type commit-msg
uv run pre-commit install
```

### 3. Running Tests & Quality Checks
```bash
# Run unit tests (offline)
uv run pytest

# Run all pre-commit linters and type checkers
uv run pre-commit run --all-files
```

---

## Configuration

| Environment Variable | Description | Default |
| :--- | :--- | :--- |
| `GOOGLE_CLOUD_PROJECT` | GCP Project ID where the agent and BigQuery reside | Defaults to active `gcloud` project |
| `GOOGLE_CLOUD_LOCATION` | Google Cloud location for model calls | `us-central1` |
| `GOOGLE_CLOUD_SKILL_LOCATION` | Region for Google Cloud Skill Registry (`us`, `eu`, `global`) | `us` |
| `BQ_AGENT_MODEL` | Gemini model ID used by the agent | `gemini-3.8-flash` |

---

## Evaluation

The agent ships an ADK evaluation harness under `tests/evals/`:

- `bq_agent.evalset.json` — single-turn core cases (trajectory, SQL safety, grounded answers) against the public `bigquery-public-data.usa_names.usa_1910_2013` dataset.
- `test_config.json` — criteria & thresholds (trajectory IN_ORDER match, LLM-judged response/rubric/hallucination criteria). Efficiency metrics are reported automatically on every run.
- `multiturn/` — scenario-based multi-turn evals (user simulation) with their own `test_config.json`: a cost-bounded smoke scenario that runs in pytest, plus an on-demand extended suite (CLI only).
- `baselines/` — each pytest run archives its results JSON here.

Prerequisites:

1. `gcloud auth application-default login` with access to BigQuery public datasets.
2. `GOOGLE_CLOUD_PROJECT` set; `aiplatform.googleapis.com` (incl. the Vertex Gen AI Evaluation Service used by LLM-judged criteria) enabled.
3. Env from `src/agent/.env.example` (`GOOGLE_GENAI_USE_VERTEXAI=true`, `GOOGLE_CLOUD_LOCATION`).

Run (gated behind `RUN_ADK_EVAL`; plain `uv run pytest` stays offline). Three tiers, cheapest first:

```bash
# Tier 1 — smoke (per-PR; trajectory-only, no LLM judges, cents):
RUN_ADK_EVAL=smoke uv run pytest tests/test_eval.py -v
# Tier 2 — gate (nightly / pre-release; full single-turn criteria, 1 run/case):
RUN_ADK_EVAL=gate uv run pytest tests/test_eval.py -v
# Tier 3 — full (milestones/tuning; multi-turn scenarios only, 3 runs/case):
RUN_ADK_EVAL=full uv run pytest tests/test_eval.py -v
# extended multi-turn scenarios (manual, CLI only):
uv run adk eval src/agent/app tests/evals/multiturn/bq_agent_conversations_extended.evalset.json \
  --config_file_path=tests/evals/multiturn/test_config.json --print_detailed_results
```

Cost note: the BigQuery MCP toolset is filtered to the 6 query/metadata tools the agent actually uses (`BQ_MCP_TOOL_ALLOWLIST` in `bq_mcp_client.py`); the dropped job-management tools carried ~78% of the schema tokens. After filtering, an invocation's prompt is ~44K tokens (was ~165K+), and Vertex implicit caching discounts the stable prefix further within a session. Budget tiers accordingly; see the report for the measured anatomy.

See `tests/evals/EVALUATION_REPORT.md` for the latest baseline results and analysis. The easiest way to add cases is the **Eval** tab in `uv run adk web src/agent`: run a real session, then save it as an eval case.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
