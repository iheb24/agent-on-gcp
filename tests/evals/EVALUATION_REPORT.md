# Evaluation Report — bq_agent

- Date: 2026-10-07 (baseline arc), 2026-10-09 (optimization round)
- Author: project maintainers
- Agent model: `gemini-3.8-flash` (resolved from `BQ_AGENT_MODEL` default)
- Toolchain: google-adk 2.10.0, google-genai 2.25.0, google-cloud-aiplatform 2.2.0,
  eval-time dev deps: pandas 3.0.6, rouge-score 0.1.2, tabulate 0.10.0, jinja2 3.1.6
- Evalset: tests/evals/bq_agent.evalset.json (3 cases, `num_runs=2` → 6 invocations)
- Config: tests/evals/test_config.json
- Baseline of record: tests/evals/baselines/bq_agent_core_20261007_182936.json (gate PASSED)
- Command:

  ```bash
  RUN_ADK_EVAL=1 GOOGLE_GENAI_USE_VERTEXAI=true GOOGLE_CLOUD_PROJECT=<project> \
    GOOGLE_CLOUD_LOCATION=global uv run pytest tests/test_eval.py -v
  ```

## What was evaluated and why

Single-turn core behavior of the BigQuery assistant: (1) deterministic tool
trajectory smoke checks — the right key tools in the right order, notably
`get_current_utc_date` before SQL on time-relative questions; (2) SQL-safety
rubrics derived from the `custom-sql-guidelines` skill (LIMIT ≤ 1000, no
`SELECT *`, Standard SQL); (3) semantic match of the structured JSON answer
against a validated reference; (4) groundedness (no invented numbers) and
safety. Reference numbers were validated against the real public dataset
before the run (the draft's Mary-2013 figure of 19,120 was wrong; the dataset
says 2,589 — the reference was fixed, not the agent).

Design notes:

- `tool_trajectory_avg_score` uses `match_type=IN_ORDER` + `ignore_args=true`
  (verified supported in ADK 2.10.0): the real agent legitimately calls
  `load_skill` and `get_table_info` around the key actions, and SQL text
  varies run to run, so EXACT/args matching would be brittle by design.
  SQL-shape enforcement lives in the rubrics instead.
- The judge model (`gemini-3.5-flash`) deliberately differs from the agent
  model to reduce self-preference bias.

## Results per criterion

Official baseline: **run 6** (`baselines/bq_agent_core_20261007_182936.json`,
gate PASSED). Scores are per-invocation; 3 cases × `num_runs=2` = 6
invocations. Earlier runs are analyzed under Failures and analysis.

| Criterion | Threshold | Score (run 6) | Pass? |
|---|---|---|---|
| tool_trajectory_avg_score | 0.8 | 1.0 (6/6) | yes |
| final_response_match_v2 | 0.7 | 1.0 (6/6) | yes |
| rubric_based_tool_use_quality_v1 | 0.8 | 1.0 (6/6) | yes |
| rubric_based_final_response_quality_v1 | 0.8 | 1.0 (6/6) | yes |
| hallucinations_v1 | 0.8 | 1.0 (6/6) | yes |
| safety_v1 | 1.0 | not evaluated — removed from config, see Failures #3 | n/a (toolchain) |

## Efficiency (auto-reported)

| Metric | Run 6 (official) | Run 2 (first calibrated) | Delta |
|---|---|---|---|
| tool_call_count_v1 (mean/invocation) | 5.3 | 5.8 | −0.5 |
| inference_call_count_v1 (mean/invocation) | 5.0 | 5.3 | −0.3 |
| token_usage_v1 (mean/invocation) | ~1.09M | ~1.16M | −6% |
| invocation_duration_v1 (mean, seconds) | 61.8 | 60.3 | +1.5s |

Note the absolute token usage: ~1.1M tokens per single-turn invocation. The
skill payloads (`load_skill` × 2), MCP tool schemas, and Gemini 3 thinking
tokens dominate; the actual SQL work is trivial by comparison. This is the
main cost driver to watch when adding cases (and when tuning
temperature/thinking level, see Part B2 of the planning doc).

## Failures and analysis

### Baseline run 1 (20261007_170601) — evalset design flaws found by the eval itself

1. **Ambiguous prompt → table drift.** Case `relative_date_count` asked about
   "the usa_names dataset" without naming a table. The agent discovered
   `usa_1910_current` (data through 2021) via `list_table_ids` and answered
   2,070 Marys in 2021 — a correct answer to the question as asked, but not
   the reference (2,589 in 2013 from `usa_1910_2013`). Fix: prompts now name
   the table explicitly; references re-validated.
2. **Wrong tool expectation.** The same case expected `get_current_utc_date`
   in the trajectory, but "last available year in the dataset" is
   *data*-relative (MAX(year) SQL is legitimate), not *clock*-relative — even
   the `relative_date_tool_first` rubric judge sided with the agent (rubric
   score 1.0 while the deterministic trajectory score was 0.0 — the criterion
   diversity caught a bad expectation, not a bad agent). Fix: case redesigned
   to be genuinely clock-relative ("I'm turning 30 this year" → birth year
   1996 → Mary count 6,937, validated).
3. **`safety_v1` NOT_EVALUATED on all 6 invocations** — toolchain
   incompatibility, not an agent failure: ADK 2.10.0's
   `_SingleTurnVertexAiEvalFacade` builds `vertexai.types.EvaluationDataset`,
   which under google-cloud-aiplatform 2.2.0 resolves to
   `agentplatform._genai.types` classes that `vertexai._genai.evals.evaluate`
   rejects (`TypeError: Unsupported dataset type`). google-adk 2.11.0 still
   pins `google-cloud-aiplatform[evaluation]<2`, i.e. upstream considers
   aiplatform 1.x the supported eval path. Versions recorded per standing
   rule: google-adk 2.10.0, google-cloud-aiplatform 2.2.0. `hallucinations_v1`
   and the rubric/final-response judges do NOT use this facade (direct genai
   judge calls) and are unaffected.
4. **`hallucinations_v1` NOT_EVALUATED on 2/6 invocations** — judge-side
   transient (segmenter/validator judge uses default judge model); observed
   flakiness input for threshold calibration.
5. **Judge leniency observed**: `final_response_match_v2` scored 1.0 for the
   2021/2,070 answer vs the 2013/2,589 reference (question was ambiguous, so
   the judge credited a correct-but-different answer). With table-pinned
   prompts this should not recur; keep an eye on it for threshold calibration.

### Baseline run 2 (20261007_172728) — calibrated evalset

All scored criteria at 1.0 across all cases. Only `safety_v1` failed the run
(never scores on this toolchain, see #3 above) and one transient
`hallucinations_v1` NOT_EVALUATED was absorbed by the per-case mean (ADK
averages non-empty scores per case; a metric only fails the gate when an
entire case produces no score — verified in `agent_evaluator.py`).

### Baseline run 3 (20261007_173953) — final config (safety_v1 removed)

`safety_v1` removed → gate logic no longer fails on the toolchain gap. All
criteria 1.0 **except** `hallucinations_v1` = 0.667 on one
`relative_date_count` run: the judge flagged one of three sentences as
ungrounded. Manual inspection: all three claims (current year 2026 → birth
year 1996 arithmetic; 6,937 from the validated SQL result) are grounded — a
judge false positive on a *derived* (arithmetic) claim. Root cause
contributor found: criteria without explicit `judge_model_options` fall back
to the ADK default judge **`gemini-2.5-flash`** (a previous-generation model
judging a Gemini 3.8 agent). Calibration: pinned
`judge_model = gemini-3.5-flash` for all LLM-judged criteria.
`hallucinations_v1` ignores `num_samples` in ADK 2.10.0 (single verdict per
sentence), so judge quality is the only variance lever for that metric.

### Baseline run 4 (20261007_175621) — calibrated judges

Judge pinned to `gemini-3.5-flash` → the newer judge is **stricter**, and the
strict (1.0) thresholds became brittle:

- `hallucinations_v1` 0.667 on the same derived-claim sentence as run 3 —
  both judge generations flag it → this is the metric's strictness on
  arithmetic-derived claims, not a judge-quality issue.
- `rubric_based_final_response_quality_v1` 0.0 on one run for a response that
  visibly satisfies the `structured_answer` rubric (valid schema JSON, exact
  SQL, plain-language summary) — judge false negative.
- `rubric_based_tool_use_quality_v1` 0.75 on one `aggregation_top_names` run
  (one of four rubrics judged unmet; the trajectory itself was textbook:
  skills → metadata → limited, column-explicit SQL).

By contrast, runs 2–3 with the lenient default judge (`gemini-2.5-flash`)
scored the same behaviors 1.0. Lesson: judge strictness varies by judge
model; thresholds must be calibrated to the chosen judge, and 1.0 thresholds
on LLM-judged metrics are fragile with short responses (one flagged sentence
out of three = 0.667; one false-negative rubric out of four = 0.75). The
deterministic criterion (`tool_trajectory_avg_score`, IN_ORDER) remained 1.0
in every run — it is the reliable hard gate.

**Calibration decision (2026-10-07):**
judge stays `gemini-3.5-flash` (deliberate, current-gen, distinct from the
agent model); judge-scored thresholds loosened to match observed judge
variance: `hallucinations_v1` 1.0 → 0.8 (still fails when ≥2 of 3 sentences
are ungrounded), `rubric_based_tool_use_quality_v1` 1.0 → 0.8 (per-case mean
over `num_runs=2` absorbs a single-run rubric false negative: 0.875 passes,
≤0.75 fails). `final_response_match_v2` 0.7,
`rubric_based_final_response_quality_v1` 0.8, and the deterministic
`tool_trajectory_avg_score` 0.8 unchanged.

### Baseline run 5 (20261007_181944) — loosened thresholds + a REAL agent bug

`hallucinations_v1` and `rubric_based_tool_use_quality_v1` passed at 0.8. But
`final_response_match_v2` and `rubric_based_final_response_quality_v1` both
scored 0.0 on one `explicit_limit_sample_rows` run. Two independent judges
agreeing on 0.0 pointed at the response, not the judges — and indeed: the
final response was **187 chars of truncated, invalid JSON**. Gemini 3 thinking
tokens consume the `max_output_tokens=1024` budget, occasionally leaving
almost nothing for the visible answer (the exact failure mode the planning
doc flagged: "watch for truncation with thinking tokens… bump to 2048 if seen
in traces"). Observed frequency: 1 in ~30 invocations — a latent production
defect (schema-invalid answers) that unit tests could never catch.

**Fix applied:** `max_output_tokens` 1024 → 2048 in
`src/agent/app/agent.py` (headroom only; sampling behavior unchanged).

### Baseline run 6 (20261007_182936) — truncation fix verification — GREEN

**Gate: PASSED** (`1 passed` in 8m16s). All criteria 1.0 on all 6
invocations; zero truncated responses. This run — calibrated evalset,
calibrated judges, calibrated thresholds, `max_output_tokens=2048` — is the
official baseline of record. Efficiency: 5.3 tool calls / 5.0 inference
calls / ~1.09M tokens / 61.8s mean per invocation.

## Observations on the migration

- No `set_model_response` call appears in any trace (native `output_schema` +
  tools on Vertex AI). Note: this held for `gemini-2.5-flash` too — ADK 2.10
  gates the shim on the Gemini API variant, not the model family — so this
  confirms the Vertex configuration, not Gemini 3 specifically.
- `gemini-3.8-flash` accepts the legacy `temperature=0.1, top_p=0.8, top_k=40`
  config on Vertex `global` (no API error), so the migration kept
  `generate_content_config` untouched.
- Latency: 45–198s per single-turn invocation (mean ~60s calibrated), dominated
  by skill loading + thinking tokens; ~1.2–2.0M total tokens per invocation.
  No direct 2.5-flash comparison was recorded (migration predates the
  harness); the A/B in Part F #7 can produce one if needed.

## Decisions taken

- MCP tool names verified from live traces on 2026-10-07: the server prefers
  `execute_sql_readonly` for SELECTs (evalset updated from the `execute_sql`
  placeholder); observed live pattern: `load_skill` × 2 → `get_table_info` →
  `execute_sql_readonly`.
- Reference data validated against the real dataset (Mary 2013 = 2,589;
  CA top-3 male = Michael 420,127 / David 362,813 / Robert 346,828).
- Eval dependencies: added `pandas`, `rouge-score`, `tabulate`, `jinja2` to the
  `dev` extra instead of `google-adk[eval]` — the full extra pins
  `google-cloud-aiplatform<2`, conflicting with this repo's `>=2.2.0`; the
  installed aiplatform 2.2.0 already provides the `vertexai.types.evals`
  surface the ADK eval facade uses.
- `AgentEvaluator.evaluate` requires `agent_module` to expose `agent` or end
  with `.agent` → harness uses `src.agent.app.agent`.
- `safety_v1` removed from `test_config.json` on 2026-10-07: it routes through
  `_SingleTurnVertexAiEvalFacade`, which is incompatible with
  google-cloud-aiplatform 2.2.0 (see Failures #3) and can never score —
  and a metric that produces no score for an entire case fails the gate by
  design. Re-add `"safety_v1": {"threshold": 1.0}` once ADK supports
  aiplatform 2.x (or run evals in a dedicated venv with
  `google-adk[eval]` / aiplatform 1.x if safety gating becomes a hard
  requirement — noting the agent would then be judged under a different
  aiplatform major than it deploys with).
- Threshold calibration (2026-10-07): judge-scored thresholds
  loosened after 4 runs of variance evidence — `hallucinations_v1` and
  `rubric_based_tool_use_quality_v1` 1.0 → 0.8; judges pinned to
  `gemini-3.5-flash` for all LLM-judged criteria (ADK default is
  `gemini-2.5-flash`). Deterministic `tool_trajectory_avg_score` stays the
  hard gate at 0.8. Details in Failures, runs 3–5.
- `max_output_tokens` 1024 → 2048 after run 5 caught thinking-token
  truncation producing invalid-JSON answers (1 in ~30 invocations).
- Temperature/thinking-level: unchanged (`temperature=0.1` kept from the 2.5
  era; Gemini 3 default is 1.0). Baselines are stable enough that an A/B
  experiment (Part F #7) is now meaningful.

## Phase 3 — Multi-turn evaluation (scenario-based, user simulation)

### Design constraints discovered (verified against google-adk 2.10.0)

1. **The dedicated multi-turn metrics are hard-blocked on this toolchain.**
   `multi_turn_task_success_v1`, `multi_turn_trajectory_quality_v1`, and
   `multi_turn_tool_use_quality_v1` all delegate to
   `_MultiTurnVertexiAiEvalFacade` — the same aiplatform-2.2.0-incompatible
   path as `safety_v1` (Failures #3), proven offline:
   `vertexai.types.EvaluationDataset` resolves to
   `agentplatform._genai.types…` while `vertexai._genai._evals_common`
   type-checks against the legacy `vertexai._genai.types…` class; they are
   not the same class. Decision (2026-10-07): use
   **`rubric_based_multi_turn_trajectory_quality_v1`**, which extends the
   direct-genai `RubricBasedEvaluator` path proven in Phase 2. The scenario
   evalset is metric-agnostic — the dedicated metrics can be layered on
   later without evalset changes.
2. **Conversations are unbounded by default** (`while True` loop in
   `evaluation_generator.py`; only the simulator's stop signal or
   `max_allowed_invocations` ends them — default 20). An unbounded first
   attempt ran 76+ minutes at ~1M+ tokens/turn before being killed for cost.
3. **`user_persona` is a registry ID** (`NOVICE`, `EXPERT`, `EVALUATOR`),
   not free text; `custom_instructions` is a full Jinja template replacement
   (requires `{{ stop_signal }}`, `{{ conversation_plan }}`,
   `{{ conversation_history }}`) — avoid; put ending guidance in
   `conversation_plan` instead.

### Cost-bounded smoke design (2026-10-07)

- `tests/evals/multiturn/bq_agent_conversations.evalset.json`: ONE scenario
  (`context_carryover_gender_filter`), `max_allowed_invocations=5`. Ran as
  `num_runs=1` smoke on 2026-10-07 (~1.5M tokens, ~3 min); with the tiered
  strategy (2026-10-09) it runs only in tier `full` at `num_runs=3`.
- `tests/evals/multiturn/bq_agent_conversations_extended.evalset.json`:
  on-demand scenarios (progressive disclosure + yearly-granularity
  pushback), run manually:
  `uv run adk eval src/agent/app tests/evals/multiturn/bq_agent_conversations_extended.evalset.json --config_file_path=tests/evals/multiturn/test_config.json`
- Rubrics (threshold 0.8, judge `gemini-3.5-flash`): task success with real
  data, no fabricated monthly granularity, context carryover, SQL safety,
  efficient tool use.

### Multi-turn baseline (bq_agent_conversations_20261007_211438) — GREEN

Gate PASSED, `rubric_based_multi_turn_trajectory_quality_v1` = 1.0. Turn
anatomy: turn 1 = 5 tool calls / ~1.09M tokens / 60s (skills, metadata,
SQL); turn 2 = **1 tool call** (only `execute_sql_readonly`) / ~0.44M tokens
/ 17s — textbook context carryover: no metadata re-discovery, no repeated
questions, just the filtered query.

## Phase 4 decision: conformance suite — NO-GO for now (2026-10-09)

### What ADK conformance testing is

`adk conformance record|test` builds a golden-baseline regression gate: a
real session is recorded (via `adk web` + `RecordingsPlugin`) into
`tests/conformance/<case>/spec.yaml` + recordings, and replay mode then
**mocks the LLM** and diffs what the agent *sends* — system instruction,
tool definitions, tool-call sequence, request payloads — against the
recording. It is free (no LLM calls), fast, and deterministic: a per-PR
gate that catches drift in the agent's request shape without spending eval
tokens.

### Why not now — evidence from this evaluation arc

1. **The request shape is still in flux.** Conformance recordings bake in
   the exact request the agent produces. Within this single week the agent's
   request changed twice (model migration; `max_output_tokens` 1024 → 2048),
   and the temperature/thinking-level A/B (planning doc Part F #7) is still
   pending — each intentional change invalidates every recording.
   Recording now means re-recording soon; that is churn, not signal.
2. **Replay diffs are exact, the remaining variance is semantic.** The
   failure modes this evaluation actually found (truncated JSON under
   thinking-token pressure, table ambiguity, judge strictness) would NOT be
   caught by a mocked-LLM replay — replay does not detect live model drift
   at all (the planning doc already encodes this caveat). Conversely, benign
   request changes (a reworded instruction) would fail the gate loudly.
   High false-positive rate on expected changes, blind to the failures
   actually observed.
3. **Coverage overlap.** The behavioral contract conformance would pin —
   right tools, right order, correct instruction/tool definitions — is
   already covered semantically by the calibrated single-turn gate
   (`tool_trajectory_avg_score` IN_ORDER + rubrics) and now by the
   multi-turn smoke. The incremental value of a second, byte-exact gate is
   low while the config is moving.
4. **Standing Rule 5 (keep it lightweight).** A conformance suite is a
   maintained artifact: re-record on every intentional model/instruction/
   tool change. For a 3-tool single agent with a green eval gate, that
   maintenance buys little today.

### When to revisit (adoption triggers)

- The temperature/thinking-level experiment has landed and
  `generate_content_config` has been stable for several weeks → record
  baselines then; they will actually stay valid.
- Judge variance ever makes the LLM-judged gate flaky in practice →
  conformance becomes the free deterministic per-PR gate and the eval suite
  drops to nightly (the CI split the planning doc's Part F #6 anticipated).
- The agent grows (more tools, sub-agents, routing) so that request-shape
  drift becomes a real risk worth byte-exact pinning.

### How to adopt when triggered (no re-derivation needed)

```bash
uv run adk web -v \
  --extra_plugins=google.adk.cli.plugins.recordings_plugin.RecordingsPlugin \
  src/agent        # record one session per case
uv run adk conformance record tests/conformance/core/<case> none
uv run adk conformance test tests/conformance --generate_report --report_dir=reports
```

Specs live at `tests/conformance/<case>/spec.yaml`; the `agent:` field is
the directory name ADK discovers under the served path (`app` when serving
`src/agent`), verified in the planning doc. Re-record on every intentional
model/instruction/tool change.

## Optimization round (2026-10-09) — token anatomy and tiered strategy

### Root cause of the high eval cost (found by measuring, not guessing)

`token_usage_v1` sums the **full prompt of every model call** in an
invocation (plus output + thinking). Measurement of the BigQuery MCP
toolset's declarations: **~157K tokens of tool schema**, of which the
job-management tools `cancel_job` and `get_job` alone carry ~118K (75%) —
tools this read-only assistant never called in any traced invocation. With
~5 model calls per question re-sending that prefix, one "simple question"
registered ~1.1M tokens. LLM judges multiplied this further (each judge call
carries the trajectory; `num_samples=5` votes; `num_runs=2`; an unbounded
first multi-turn attempt).

### Fixes applied (behavior-preserving)

1. **Tool allowlist** — `BQ_MCP_TOOL_ALLOWLIST` in
   `src/agent/app/adapters/bq_mcp_client.py` keeps the six query/metadata
   tools (`execute_sql_readonly`, `execute_sql`, `get_table_info`,
   `get_dataset_info`, `list_table_ids`, `list_dataset_ids`) and drops the
   job-management trio. Live probe after the change: prompt **~44K
   tokens/call (was ~165K+, −73%)**, agent trajectory unchanged
   (skills → metadata → readonly SQL → JSON answer).
2. **Context caching** — `App(context_cache_config=ContextCacheConfig())`
   ([docs](https://adk.dev/context/caching/)); cached prefix reads are
   discounted (~75-90% on Vertex). Bonus finding from the probe: Vertex
   **implicit caching is already active** — later calls in a session showed
   ~39K of ~44K prompt tokens served as cached reads.
3. **Judge economy** — `final_response_match_v2` `num_samples` 5 → 3.

### Tiered run strategy (replaces the single all-or-nothing suite)

| Tier | `RUN_ADK_EVAL` | Content | Cost profile | When |
|---|---|---|---|---|
| 0 | — | offline unit tests | $0 | every commit |
| 1 | `smoke` | `evals/smoke/` — 2 cases, trajectory-only (no judges) | cents | per PR |
| 2 | `gate` | full single-turn suite, `num_runs=1` | low | nightly / pre-release |
| 3 | `full` | multi-turn scenarios ONLY, `num_runs=3` | highest | milestones / tuning |

First `full` run post-optimization (bq_agent_conversations_20261009_210450):
**PASSED** in 5m36s — rubric scores 1.0 / 0.8 / 1.0 across the 3 runs (case
mean 0.93 ≥ 0.8); agent-side tokens ~1.54M total (one outlier invocation at
766K; median ~180K) vs ~1.5M for a single pre-filter conversation. Estimated
total run cost ≈ $2–3 including simulator + judge calls — matching the
predicted $2–5 range; the same run pre-filter would have been ~$15–25.
The judge remains the dominant share (`num_samples` defaults to 5 in the
multiturn config; setting it to 3 saves ~40% of that share).

Criteria configs are discovered per-folder, so tier 1 lives in
`tests/evals/smoke/` with its own `test_config.json`.

## Reproduce

```bash
gcloud auth application-default login
uv sync --all-extras
export GOOGLE_GENAI_USE_VERTEXAI=true GOOGLE_CLOUD_PROJECT=<project> GOOGLE_CLOUD_LOCATION=global

# pick a tier: smoke (per-PR) | gate (nightly) | full (multi-turn x3)
RUN_ADK_EVAL=smoke uv run pytest tests/test_eval.py -v

# results archive: tests/evals/baselines/*_<utc timestamp>.json
```

Cost note: post-filter, an invocation's prompt is ~44K tokens (~165K+
before); the stable prefix is additionally cache-discounted within a
session. Keep `num_runs` and scenario counts deliberate — judges and
simulators multiply the agent's own cost.
