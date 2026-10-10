import os
import pathlib
from datetime import UTC, datetime

from google.adk import Agent
from google.adk.agents.context_cache_config import ContextCacheConfig
from google.adk.apps import App
from google.adk.integrations.skill_registry import GCPSkillRegistry
from google.adk.skills import load_skill_from_dir
from google.adk.tools.skill_toolset import SkillToolset
from google.genai import types
from pydantic import BaseModel, Field

from .adapters.bq_mcp_client import initialize_bq_mcp

project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", "my-project")
skill_location = os.environ.get("GOOGLE_CLOUD_SKILL_LOCATION", "us")
agent_model = os.environ.get("BQ_AGENT_MODEL", "gemini-3.8-flash")

# 1. Official Managed MCP Server (authenticated via ADC, see adapters/)
bq_mcp = initialize_bq_mcp()


# 2. Custom Python Tool
def get_current_utc_date() -> str:
    """Returns the current UTC date and time in ISO 8601 format. Useful for generating time-relative SQL queries."""
    return datetime.now(UTC).isoformat()


# 3. Custom Local Skill
custom_skill_dir = pathlib.Path(__file__).parent / "skills" / "custom-sql-guidelines"
custom_skill = load_skill_from_dir(custom_skill_dir)

# 4. Managed Platform Skill ('bigquery-basics') via GCP Skill Registry
MANAGED_SKILL_NAME = "bigquery-basics"
skill_registry = GCPSkillRegistry(
    project_id=project_id,
    location=skill_location,
)

# Combined SkillToolset hosting local custom skill and connected to GCP Registry
skill_toolset = SkillToolset(
    skills=[custom_skill],
    registry=skill_registry,
)


class AgentResponseSchema(BaseModel):
    summary: str = Field(
        description="A clear, natural language summary of the dataset usage or answer to the user's question."
    )
    sql_executed: str = Field(
        description="The exact BigQuery SQL query that was executed, if any."
    )


agent = Agent(
    name="bq_agent",
    model=agent_model,
    instruction=(
        "You are a data assistant. Convert user queries to BigQuery Standard SQL, "
        "use the managed BigQuery MCP tools to execute them, and summarize the results naturally. "
        "Always use the get_current_utc_date tool when dealing with time-relative queries (e.g., 'today', 'last week'). "
        "Always follow the local 'custom-sql-guidelines' skill for organizational SQL safety and formatting constraints. "
        f"Use the load_skill tool to load the managed '{MANAGED_SKILL_NAME}' skill from the "
        "Google Cloud Skill Registry to guide dataset navigation and schema discovery."
    ),
    tools=[bq_mcp, get_current_utc_date, skill_toolset],
    output_schema=AgentResponseSchema,
    generate_content_config=types.GenerateContentConfig(
        temperature=0.1,
        top_p=0.8,
        top_k=40,
        max_output_tokens=2048,  # includes thinking tokens; 1024 truncated JSON answers (see tests/evals/EVALUATION_REPORT.md)
        safety_settings=[
            types.SafetySetting(
                category=types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
                threshold=types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
            )
        ],
    ),
)

# ADK loaders (local cli, api_server, Agent Engine) require this symbol.
root_agent = agent

# agents-cli Cloud Run serving layer (app/fast_api_app.py) imports this AdkApp.
# Context caching reuses the stable prompt prefix (instruction + tool schemas)
# from the second turn of a session on; cached reads are billed at a discount.
app = App(
    root_agent=root_agent,
    name="bq_agent",
    context_cache_config=ContextCacheConfig(),
)
