import pytest
from google.adk.skills import load_skill_from_dir
from google.adk.tools.skill_toolset import SkillToolset

from src.agent.app.agent import agent, bq_mcp, skill_toolset
from src.agent.app.skillset import CUSTOM_SKILL_DIR, MANAGED_SKILL_NAME
from src.agent.app.tools import get_current_utc_date


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
    custom_skill = load_skill_from_dir(CUSTOM_SKILL_DIR)
    assert custom_skill is not None
    assert custom_skill.frontmatter.name == "custom-sql-guidelines"

    # Check managed skill reference and assembled toolset
    assert MANAGED_SKILL_NAME == "bigquery-basics"
    assert isinstance(skill_toolset, SkillToolset)
