---
name: convoai-ios-workflow
description: Use when implementing, fixing, reviewing or continuing iOS work in this repository.
---

Read `iOS/AGENTS.md` and root `AI_WORKFLOW.md`. Work from the user's request and current code, choosing the planning, tools and checks that help the task.

Use relevant suites from `scripts/workflow.json` or other appropriate checks. Test current sources, inspect actual results and state coverage limits. Review local changes including new files, and resolve confirmed defects within scope. A standalone review returns findings without unrequested edits.

On continue, resume unfinished work from the conversation and useful notes. Notes, templates and [collaboration guidance](references/contracts.md) are optional; no fixed developer/tester sequence, response schema or state gate is required. See the [test reference](references/ios_logic_ut.md) when needed.
