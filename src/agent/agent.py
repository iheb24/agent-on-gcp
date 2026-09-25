import os
import pathlib
from datetime import datetime, timezone

import google.auth
import google.auth.transport.requests
import httpx
from google.adk import Agent
from google.adk.integrations.skill_registry import GCPSkillRegistry
from google.adk.skills import load_skill_from_dir
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams
from google.adk.tools.skill_toolset import SkillToolset
from google.genai import types
from pydantic import BaseModel, Field

project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", "my-project")
skill_location = os.environ.get("GOOGLE_CLOUD_SKILL_LOCATION", "us")


class GoogleCloudBearerAuth(httpx.Auth):
    """Attaches a fresh Google OAuth2 bearer token to every request.

    Static headers go stale because access tokens expire after ~1 hour;
    this refreshes Application Default Credentials on demand instead.
    """

    def __init__(self):
        self._credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        self._refresh_request = google.auth.transport.requests.Request()

    def auth_flow(self, request: httpx.Request):
        if not self._credentials.valid:
            self._credentials.refresh(self._refresh_request)
        request.headers["Authorization"] = f"Bearer {self._credentials.token}"
        yield request


def gcp_mcp_http_client_factory(headers=None, timeout=None, auth=None):
    """httpx client factory for GCP managed MCP servers (adds Google auth)."""
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout if timeout is not None else httpx.Timeout(60.0, read=300.0),
        auth=auth or GoogleCloudBearerAuth(),
        follow_redirects=True,
    )


# 1. Official Managed MCP Server (requires an authenticated caller)
bq_mcp = McpToolset(
    connection_params=StreamableHTTPConnectionParams(
        url="https://bigquery.googleapis.com/mcp",
        httpx_client_factory=gcp_mcp_http_client_factory,
    )
)


# 2. Custom Python Tool
def get_current_utc_date() -> str:
    """Returns the current UTC date and time in ISO 8601 format. Useful for generating time-relative SQL queries."""
    return datetime.now(timezone.utc).isoformat()


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
    model="gemini-2.5-flash",
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
        max_output_tokens=1024,
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
