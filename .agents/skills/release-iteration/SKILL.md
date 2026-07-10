---
name: release-iteration
description: Run a repo-level Android/iOS release iteration from product-source alignment through platform implementation and independent acceptance. Use for Jira, Confluence, Feishu/Lark, Figma, or direct-user requirements that should be executed through Codex without mixing private requirement data into committed infrastructure.
---

# Release Iteration

## Purpose

ConvoAI Demo is the Android and iOS showcase for Shengwang Conversational AI Engine capabilities. Requirements are proposed by the product team and carried through a complete engineering and acceptance workflow before delivery to users.

The root workflow does not define another platform state machine. Platform entrypoints, model routing, and sandbox policy come only from `references/workflow-policy.json`.

## Flow

1. Collect an explicit goal, source references, and affected platforms.
2. Create an ignored run workspace with `docs/ai-engineering/tools/run_release_iteration.py`.
3. Product reads the declared sources, confirms product intent, platforms, acceptance criteria, and whether UX is affected.
4. Knowledge grounds the requirement in repository behavior and platform-owned guidance.
5. Architect reviews every requirement and records whether a reviewed HLD is required.
6. UX Design runs for user-visible changes, followed by mandatory Test Design.
7. Selected Android and iOS workflows implement independently from their platform directories.
8. Test Verification independently checks platform and acceptance evidence.
9. UX Acceptance runs when UX Design was required.
10. A fresh read-only Acceptance Reviewer checks successful or blocked evidence.
11. The deterministic Finalizer derives `passed`, `failed`, or `blocked`.

## Rules

- Keep real issue keys, requirement details, source summaries, dependency targets, versions, and run evidence inside `docs/ai-engineering/pilot-runs/`.
- Do not copy raw private Jira, Confluence, Feishu/Lark, or Figma bodies into artifacts.
- Do not run with `--execute` until the user explicitly authorizes implementation.
- Let each platform workflow own its planning, code changes, tests, review loop, and local state rules.
- Do not introduce generic Android/iOS platform agents or duplicate platform workflow rules at the root.
- Knowledge, Architect, Test Design, Test Verification, and Acceptance Reviewer are required for every completed run.
- HLD is conditional, but the Architect decision and rationale are mandatory.
- UX Design and UX Acceptance are conditional and share one explicit Product routing decision.
- Repair is bounded by policy `max_attempts` of three; unchanged passed platforms are not rerun.
- Internal CI integration is outside this workflow.

## Command

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --name <run-name> \
  --goal "<product outcome>" \
  --source <type:reference> \
  --platform android \
  --platform ios \
  --execute
```

Omit `--execute` to inspect the generated local workspace and prompts without invoking Codex roles.

Resume a blocked or failed run after its input or environment is corrected:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 docs/ai-engineering/tools/run_release_iteration.py \
  --resume docs/ai-engineering/pilot-runs/<run> \
  --execute
```

## Privacy And Publishing

Real requirements, source summaries, HLD, UX evidence, role attempts, and acceptance evidence remain in the Git-ignored run workspace. HLD is published only after review and an explicit publishing instruction. Committed files contain only generic workflow infrastructure.
