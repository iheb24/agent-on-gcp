"""ADK evaluation harness (tiered, gated, cost-bounded).

Runs the evalsets under tests/evals/ against the live agent on GCP
(BigQuery MCP + Vertex Gen AI Evaluation Service). Disabled by default so
plain `uv run pytest` stays free and offline. Select a tier with
RUN_ADK_EVAL:

- `smoke`: deterministic trajectory checks only, no LLM judges — near-zero
  cost beyond the agent calls. Per-PR gate.
- `gate`:  full single-turn suite with calibrated LLM-judged criteria,
  num_runs=1. Nightly / pre-release.
- `full`:  multi-turn scenario suite only, num_runs=3. Calibration
  milestones and tuning experiments.

Conventions verified against the installed google-adk 2.10.0:
- `test_config.json` (criteria/thresholds) is discovered automatically in the
  SAME folder as the evalset file — there is no config parameter on
  AgentEvaluator.evaluate; tiers therefore live in separate folders.
- `num_runs` is explicit per tier so the cost profile is visible.
- Each run archives its results JSON under tests/evals/baselines/.
- `agent_module` must expose a member named `agent` or end with `.agent`
  (here: `src.agent.app.agent`, the module — not the `src.agent.app` package).
"""

import os
import pathlib
from datetime import UTC, datetime

import pytest

EVAL_DIR = pathlib.Path(__file__).parent / "evals"
SMOKE_EVALSET = EVAL_DIR / "smoke" / "bq_agent_smoke.evalset.json"
CORE_EVALSET = EVAL_DIR / "bq_agent.evalset.json"
MULTITURN_EVALSET = EVAL_DIR / "multiturn" / "bq_agent_conversations.evalset.json"
BASELINES_DIR = EVAL_DIR / "baselines"

EVAL_TIER = os.environ.get("RUN_ADK_EVAL", "")


def _skip_reason(tier: str, evalset: pathlib.Path) -> pytest.MarkDecorator:
    return pytest.mark.skipif(
        EVAL_TIER != tier or not evalset.exists(),
        reason=f"tier '{tier}' evals hit live GCP; set RUN_ADK_EVAL={tier}",
    )


async def _run(evalset: pathlib.Path, stem: str, num_runs: int) -> None:
    from google.adk.evaluation.agent_evaluator import AgentEvaluator

    BASELINES_DIR.mkdir(exist_ok=True)
    stamp = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")

    await AgentEvaluator.evaluate(
        agent_module="src.agent.app.agent",
        eval_dataset_file_path_or_dir=str(evalset),
        num_runs=num_runs,
        output_file=str(BASELINES_DIR / f"{stem}_{stamp}.json"),
    )


@_skip_reason("smoke", SMOKE_EVALSET)
@pytest.mark.asyncio
async def test_bq_agent_smoke_evalset():
    """Tier 1 (smoke): trajectory-only, deterministic, no judge calls."""
    await _run(SMOKE_EVALSET, "bq_agent_smoke", num_runs=1)


@_skip_reason("gate", CORE_EVALSET)
@pytest.mark.asyncio
async def test_bq_agent_core_evalset():
    """Tier 2 (gate): full single-turn criteria, one run per case."""
    await _run(CORE_EVALSET, "bq_agent_core", num_runs=1)


@_skip_reason("full", MULTITURN_EVALSET)
@pytest.mark.asyncio
async def test_bq_agent_multiturn_evalset():
    """Tier 3 (full): multi-turn scenario suite only, three runs per case.

    Uses tests/evals/multiturn/test_config.json (discovered by convention):
    ONLY rubric_based_multi_turn_trajectory_quality_v1 — the dedicated
    multi_turn_* metrics route through the Vertex eval facade, which is
    incompatible with google-cloud-aiplatform 2.2.0 (see EVALUATION_REPORT).
    Ground-truth criteria (tool_trajectory_avg_score, *_response_match*)
    are unsupported with user simulation and must not be added there.
    The extended scenario suite (bq_agent_conversations_extended.evalset.json)
    stays manual-only via CLI.
    """
    await _run(MULTITURN_EVALSET, "bq_agent_conversations", num_runs=3)
