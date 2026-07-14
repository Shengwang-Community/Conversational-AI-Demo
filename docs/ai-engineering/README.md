# AI Engineering Workflow

This repository delivers ConvoAI Demo requirements across Android, iOS, and Web through native Codex Agents plus deterministic policy, privacy, provenance, retry, and acceptance gates. Real requirements and run evidence stay in the Git-ignored `pilot-runs/` directory.

## Components

- `.agents/skills/release-iteration/SKILL.md`: user-facing orchestration rules.
- `.agents/skills/release-iteration/references/workflow-policy.json`: profile DAG, model, reasoning, sandbox, platform, artifact, retry, and finding routes.
- `tools/run_release_iteration.py`: run creation, native dispatch, ingestion, repair, resume, and manifest generation.
- `tools/validate_acceptance_manifest.py`: deterministic acceptance and terminal status.
- `tools/validate_artifact_privacy.py`: private-source and credential gates.
- `knowledge-index.md`: platform-owned engineering and workflow entrypoints.

## Profiles

```text
Direct:   Input -> Product/Intake -> selected platforms -> Finalizer
Standard: Input -> Product/Intake -> selected platforms -> Test Verification -> Finalizer
Full:     Input -> Product/Intake -> Knowledge -> Architect/HLD -> UX when required
          -> Test Design -> selected platforms -> Test Verification
          -> UX Acceptance when required -> Acceptance Reviewer -> Finalizer
```

`Standard` is the default. `Direct` is limited to low-risk non-UX work. `Full` is required for UX, HLD, security, migration, compatibility, shared-contract, or cross-platform design risk. Platforms run in parallel only after their common prerequisites pass.

## Model Policy

- Product, Knowledge, and Test Design: `gpt-5.6-terra`, Medium.
- Platform implementation: `gpt-5.6-sol`, Medium.
- Architect and UX: `gpt-5.6-sol`, High.
- Test Verification, UX Acceptance, and Acceptance Reviewer: `gpt-5.6-sol`, High.

Medium is the balanced default. High is reserved for roles whose independent design or verification value justifies it; increase effort only when representative evaluations show a gain. Override aliases with `AI_ENGINEERING_PRIMARY_MODEL`, `AI_ENGINEERING_SUPPORT_MODEL`, or `AI_ENGINEERING_REVIEW_MODEL`.

The prompts are outcome-first: they preserve acceptance criteria, hard constraints, permissions, evidence, and stopping conditions while leaving search and implementation steps to the model.

## Use

Give Codex the outcome, source references, affected platforms, and implementation authorization. The Lead invokes the skill and owns internal runner calls; developers do not manage workflow state.

Internal creation reference:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --name example-change \
  --goal "Demonstrate the requested Conversational AI capability" \
  --source jira:PROJECT-123 \
  --profile auto \
  --platform android \
  --platform ios \
  --platform web
```

Add `--implementation-authorized` only after explicit user authorization. Dispatch all ready platforms in parallel, then ingest their role-result paths and native Agent IDs in one command. Ingestion validates schema, readiness, attempt, artifact hashes, finding routes, privacy, contract evidence, repository fingerprints, and provenance before mutating state.

Do not use `--execute`; nested Codex process execution is rejected.

## Gap Ownership

Only Product can populate `accepted_gaps`, and every approval has a stable `gap_id`. Downstream Agents use `accepted_gap_refs`. Duplicate approvals, conflicting owners/release impact, unknown refs, and unapproved gaps fail deterministic validation.

## Status And Privacy

Statuses are `in_progress`, `blocked`, `failed`, `passed_with_mock_contract`, and `passed`. Only `passed` is production-ready and requires confirmed sanitized response, JSON Schema, or OpenAPI evidence.

Real source bodies, source summaries, Agent results, HLD, UX evidence, attempts, and acceptance artifacts remain ignored. HLD publication requires explicit instruction. Changed-line privacy is the dispatch/finalization gate; full scanning remains the baseline audit.

## Verify

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s docs/ai-engineering/tools -p '*_test.py'
python3 docs/ai-engineering/tools/validate_artifact_privacy.py --changed-lines .
python3 docs/ai-engineering/tools/validate_artifact_privacy.py \
  docs/ai-engineering .agents/skills/release-iteration Android/.agents iOS/.agents
```

Design basis: [Using GPT-5.6](https://developers.openai.com/api/docs/guides/latest-model) and [Prompting guidance for GPT-5.6 Sol](https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6).
