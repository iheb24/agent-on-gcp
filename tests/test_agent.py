import pytest

from src.agent.agent import (
    MANAGED_SKILL_NAME,
    agent,
    bq_mcp,
    custom_skill,
    get_current_utc_date,
    skill_toolset,
)


@pytest.mark.asyncio
async def test_agent_initialization():
    """Test that the agent is properly instantiated with the correct config and tools."""
    assert agent.name == "bq_agent"
    assert agent.model == "gemini-2.5-flash"
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
