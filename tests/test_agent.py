import pytest

from src.agent.agent import agent, bq_client


@pytest.mark.asyncio
async def test_agent_initialization():
    """Test that the agent is properly instantiated with the correct config."""
    assert agent.name == "bq_agent"
    assert agent.model == "gemini-2.5-flash"
    assert len(agent.tools) == 1

    # Check that tools is the query_bigquery function
    tool = agent.tools[0]
    assert tool.__name__ == "query_bigquery"


@pytest.mark.asyncio
async def test_adapter_initialization():
    """Test that the adapters are configured."""
    assert bq_client is not None
