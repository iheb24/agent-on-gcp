import pytest

from src.agent.app.adapters.bq_mcp_client import BQ_MCP_TOOL_ALLOWLIST
from src.agent.app.agent import (
    MANAGED_SKILL_NAME,
    agent,
    agent_model,
    bq_mcp,
    custom_skill,
    get_current_utc_date,
    skill_toolset,
)


@pytest.mark.asyncio
async def test_agent_initialization():
    """Test that the agent is properly instantiated with the correct config and tools."""
    assert agent.name == "bq_agent"
    assert agent.model == agent_model
    assert agent.model.startswith(
        "gemini-3"
    ), "eval assumes native output_schema+tools support"
    assert len(agent.tools) == 3

    # Check tools: Managed MCP, Custom Function, and Unified SkillToolset
    assert bq_mcp in agent.tools
    assert get_current_utc_date in agent.tools
    assert skill_toolset in agent.tools


@pytest.mark.asyncio
async def test_skills_configuration():
    """Test that both custom local skill and managed skill references are configured."""
    # Check custom local skill
    assert custom_skill is not None
    assert custom_skill.frontmatter.name == "custom-sql-guidelines"

    # Check managed skill reference
    assert MANAGED_SKILL_NAME == "bigquery-basics"
    assert skill_toolset is not None


def test_bq_mcp_tool_allowlist():
    """The MCP toolset exposes only query/metadata tools (job-management tools
    carry ~78% of the schema token cost and are never used by this agent)."""
    assert "execute_sql_readonly" in BQ_MCP_TOOL_ALLOWLIST
    assert "execute_sql" in BQ_MCP_TOOL_ALLOWLIST
    for job_tool in ("cancel_job", "get_job", "get_query_results"):
        assert job_tool not in BQ_MCP_TOOL_ALLOWLIST
    assert len(BQ_MCP_TOOL_ALLOWLIST) <= 6
