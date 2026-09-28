"""Pydantic schemas scoping the agent's input and output."""

from pydantic import BaseModel, Field


class AgentResponseSchema(BaseModel):
    summary: str = Field(
        description="A clear, natural language summary of the dataset usage or answer to the user's question."
    )
    sql_executed: str = Field(
        description="The exact BigQuery SQL query that was executed, if any."
    )
