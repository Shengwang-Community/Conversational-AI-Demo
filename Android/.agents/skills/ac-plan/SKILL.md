---
name: ac-plan
description: Freeze an Execution Contract for code or docs workflow tasks in this Android repo. Use at workflow start, after unfreeze, or whenever scope, files, checks, or constraints change before execution.
---

1. Read the active task state file; create it from `docs/TASK_STATE_TEMPLATE.md` if missing.
2. Use `$ac-memory` to validate the active task state structure and refresh the current state summary before planning.
3. Define task goal, scope boundary, forbidden changes, and acceptance checks.
4. Fill `Execution Contract` completely with real repo paths and task-appropriate checks:
- Scope
- Files to change
- Forbidden
- Steps
- Checks
- Commit plan
- Rollback note
4.5. The frozen Contract must be concrete enough for direct execution:
- list `Files to change` as specifically as practical
- write `Steps` as an ordered execution sequence, not abstract intentions
- name concrete `Checks` such as commands, consistency searches, manual paths, or review checks
- for docs / skills / templates tasks, list the coupled files that must stay in sync
5. For development-stage integration or debugging tasks, encode review boundaries directly into the existing Contract fields and state:
- local cache / debug data policy
- backend contract assumptions used in this round
- explicit non-goals for this task
- which suspicious behaviors should remain in `Gaps` as `assumption` / `open question` unless contradicted by evidence
6. If the user request contains an exact review trigger, or the subtype has already been recorded in the Contract, plan against that mode:
- `开发态联调 review` -> dev-stage integration review
- `问题修复 review` -> fix / regression review
7. If the task touches `AGENTS.md`, `.agents/skills`, or `docs/*.md`, include all coupled files that must stay in sync.
8. Update `下一步 Top 3` and append `关键决策日志`.
9. Set `PLAN_FROZEN: true`, `CURRENT_ROLE: planner`, and `WORKFLOW_STATUS: active`.
10. Emit a concise state summary for the caller to echo when helpful, then hand off to `$ac-execute`.

Hard rules:

- Do not implement feature or document changes in this skill.
- Do not hand off if Contract fields are incomplete.
- Do not freeze generic placeholders or non-existent repo paths as final scope.
- Do not freeze vague steps such as “update docs” or “do review” as final execution detail.
- Do not leave `Checks` at “self-test” or other non-specific placeholders when a concrete search, command, or manual path can be named.
- Do not leave development-stage review assumptions as private reasoning; they must be visible in Contract/Evidence/Gaps.
- Do not infer a review subtype from vague wording when the exact trigger phrase was not provided.
