# AI Engineering Workflow

ConvoAI Demo is the Android and iOS showcase for Shengwang Conversational AI Engine capabilities. Requirements are proposed by the product team and carried through a complete engineering and acceptance workflow before delivery to users.

Real requirements and run evidence are written only to the Git-ignored `pilot-runs/` directory.

## Architecture

- `.agents/skills/release-iteration/SKILL.md`: Codex workflow entrypoint and guardrails.
- `.agents/skills/release-iteration/references/workflow-policy.json`: the single DAG, model, sandbox, platform, artifact, `max_attempts`, and finding-routing source.
- `tools/run_release_iteration.py`: private run creation, execution, repair, and resume state machine.
- `tools/codex_executor.py`: least-privilege Codex execution and validated role-result promotion.
- `tools/validate_acceptance_manifest.py`: deterministic Finalizer and acceptance gate.
- `tools/validate_artifact_privacy.py`: private-source and credential guard.
- `knowledge-index.md`: platform-owned workflow and architecture guidance.

The complete sequence is:

```text
Input Gate
-> Product
-> Knowledge
-> Architect / conditional HLD
-> conditional UX Design
-> Test Design
-> selected Android and iOS workflows
-> Test Verification
-> conditional UX Acceptance
-> Acceptance Reviewer
-> deterministic Finalizer
```

Knowledge, Architect, Test Design, Test Verification, and Acceptance Reviewer are mandatory. HLD and both UX stages are conditional but require explicit routing decisions and reasons. Automatic repair is limited to policy `max_attempts` of three. Android and iOS execute independently, so one platform failure does not hide the other platform result.

Platform implementation remains owned by `Android/AGENTS.md`, `Android/.agents/skills/ac-workflow/SKILL.md`, and `iOS/.agents/skills/convoai-ios-workflow/SKILL.md`.

## Run

Create a public-safe private run workspace:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --name example-change \
  --goal "Demonstrate the requested Conversational AI Engine capability" \
  --source jira:PROJECT-123 \
  --platform android \
  --platform ios
```

Add `--execute` only when implementation has been explicitly authorized. Resume after correcting blocked input or environment evidence:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --resume docs/ai-engineering/pilot-runs/<run> \
  --execute
```

Model defaults can be replaced with `AI_ENGINEERING_PRIMARY_MODEL` and `AI_ENGINEERING_REVIEW_MODEL`.

## Boundaries

Real requirements, source summaries, HLD, UX evidence, attempts, and acceptance artifacts remain ignored. HLD publishing requires completed review and an explicit publishing instruction. Internal CI integration is out of scope.

## Verify

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s docs/ai-engineering/tools -p '*_test.py'
python3 docs/ai-engineering/tools/validate_acceptance_manifest.py \
  docs/ai-engineering/pilot-runs/<run>/acceptance-manifest.json
```
