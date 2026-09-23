import os

from google.adk import Agent
from google.genai import types
from pydantic import BaseModel, Field

from src.agent.adapters.bq_mcp_client import BQMCPClientAdapter

project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", "my-project")
location = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

bq_client = BQMCPClientAdapter(project_id=project_id, location=location)


class AgentResponseSchema(BaseModel):
    summary: str = Field(
        description="A clear, natural language summary of the dataset usage or answer to the user's question."
    )
    sql_executed: str = Field(
        description="The exact BigQuery SQL query that was executed, if any."
    )


async def query_bigquery(sql: str) -> str:
    """Executes a BigQuery Standard SQL query and returns the data."""
    await bq_client.connect()
    try:
        result = await bq_client.call_tool("query", {"sql": sql})
        bq_data = ""
        if result.content:
            for c in result.content:
                if c.type == "text":
                    bq_data += c.text
        return bq_data
    except Exception as e:
        return f"Error executing query: {str(e)}"
    finally:
        await bq_client.disconnect()


agent = Agent(
    name="bq_agent",
    model="gemini-2.5-flash",
    instruction="You are a data assistant. Convert user queries to BigQuery Standard SQL, use the query_bigquery tool to execute them, and summarize the results naturally.",
    tools=[query_bigquery],
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
