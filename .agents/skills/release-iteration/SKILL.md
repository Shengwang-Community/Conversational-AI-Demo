---
name: release-iteration
description: Deliver a repo-level Android, iOS, or Web release iteration from Jira, Confluence, Feishu/Lark, Figma, or direct requirements through implementation and deterministic acceptance without committing private source content.
---

# Release Iteration

Deliver the requested ConvoAI Demo outcome across the selected platforms. The Lead owns orchestration; native Codex Agents own judgment and implementation; repository tools own state, privacy, provenance, retries, and final status.

## Select A Profile

Product/Intake reads every declared source and selects:

- `direct`: low-risk, non-UX work with no HLD, security, migration, compatibility, shared-contract, or cross-platform design risk. Flow: Product -> platforms -> Finalizer.
- `standard`: default for ordinary delivery. Flow: Product -> platforms -> Test Verification -> Finalizer.
- `full`: UX, HLD, security, migration, compatibility, shared-contract, or cross-platform design risk. Flow: Product -> Knowledge -> Architect -> UX when required -> Test Design -> platforms -> Test Verification -> UX Acceptance when required -> Acceptance Reviewer -> Finalizer.

An explicit `--profile` is a hard constraint. With `auto`, Product chooses using the criteria above.

## Run

1. Collect the outcome, source references, declared platforms, and implementation authorization.
2. Verify source MCP access and create an ignored run workspace with `docs/ai-engineering/tools/run_release_iteration.py`.
3. Dispatch every ready native Agent with the exact model, reasoning, sandbox, working directory, prompt, and result path returned by the runner.
4. Dispatch independent ready platforms in parallel and ingest their results as one batch.
5. Continue until no dispatch is ready and the deterministic Finalizer returns a terminal status.

Do not ask the user to manage runner commands. Do not use `--execute` or start nested `codex exec` processes.

## Invariants

- Keep raw Jira, Confluence, Feishu/Lark, Figma, internal links, source summaries, and run evidence inside `docs/ai-engineering/pilot-runs/`.
- Do not authorize platform implementation until the user explicitly asks to implement.
- Follow platform entrypoints for local engineering and validation rules.
- Preserve the native Agent ID and requested/attested provenance distinction.
- Let Agents choose efficient steps; retain hard constraints, acceptance criteria, permissions, evidence, and stopping conditions.
- Use multi-Agent execution only for ready workstreams that are genuinely independent. Keep dependent design, implementation, and acceptance sequential.
- Retry actionable findings at most policy `max_attempts` times. Do not rerun unchanged passed platforms.
- Internal CI integration and HLD publication remain outside the default workflow.

## Accepted Gaps

Product is the only approval authority. Each approval requires a stable `gap_id`, rationale, owner, release impact, and timestamp. Other Agents leave `accepted_gaps` empty and cite approved IDs through `accepted_gap_refs`. Keep `gaps` for unresolved, unapproved blockers; do not repeat approved exceptions there. The Finalizer deduplicates Product approvals and the validator rejects duplicate or conflicting IDs.

## Native Result Protocol

Create a run internally; include `--implementation-authorized` only after explicit authorization:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --name <run-name> \
  --goal "<product outcome>" \
  --source <type:reference> \
  --profile auto \
  --platform android \
  --platform ios \
  --platform web
```

For each dispatch, write artifacts under the ignored run workspace and return only `path` + `sha256` references in role-result JSON. Ingest parallel results together:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --resume docs/ai-engineering/pilot-runs/<run> \
  --native-result docs/ai-engineering/pilot-runs/<run>/native-results/<attempt>-android.json \
  --native-agent-id <android-agent-id> \
  --native-result docs/ai-engineering/pilot-runs/<run>/native-results/<attempt>-ios.json \
  --native-agent-id <ios-agent-id>
```

Resume after correcting an external blocker with `--retry-blocked`.

## Terminal Status

- `in_progress`: ready or repairable work remains.
- `blocked`: missing authority, input, environment, protocol, privacy, or acceptance evidence prevents progress.
- `failed`: actionable retries are exhausted.
- `passed_with_mock_contract`: local implementation and validation passed against a Product-approved mock contract.
- `passed`: all required gates passed with confirmed sanitized contract evidence.
