"""BigQuery Data Assistant agent: composition root.

Building blocks (MCP client, function tools, skill wiring, schemas) live in
their own modules; this file only assembles them into the ADK Agent.
"""

from google.adk import Agent
from google.adk.apps import App
from google.genai import types

from .adapters.bq_mcp_client import initialize_bq_mcp
from .schemas import AgentResponseSchema
from .skillset import MANAGED_SKILL_NAME, build_skill_toolset
from .tools import get_current_utc_date

bq_mcp = initialize_bq_mcp()
skill_toolset = build_skill_toolset()

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

# agents-cli Cloud Run serving layer (app/fast_api_app.py) imports this AdkApp.
app = App(root_agent=root_agent, name="bq_agent")
