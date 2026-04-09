---
name: ac-plan
description: Freeze an Execution Contract for code or docs workflow tasks in this Android repo. Use at workflow start, after unfreeze, or whenever scope, files, checks, or constraints change before execution.
---

1. Read `PROJECT_STATE.md`; create it from `docs/PROJECT_STATE_TEMPLATE.md` if missing.
2. Use `$ac-memory` to validate `PROJECT_STATE.md` structure and refresh the current `[STATE]` anchor before planning.
3. Define task goal, scope boundary, forbidden changes, and acceptance checks.
4. Fill `Execution Contract` completely with real repo paths and task-appropriate checks:
- Scope
- Files to change
- Forbidden
- Steps
- Checks
- Commit plan
- Rollback note
5. If the task touches `AGENTS.md`, `.agents/skills`, or `docs/*.md`, include all coupled files that must stay in sync.
6. Update `下一步 Top 3` and append `关键决策日志`.
7. Set `PLAN_FROZEN: true`, `CURRENT_ROLE: planner`, and `WORKFLOW_STATUS: active`.
8. Emit a `[STATE]` anchor for the caller to echo and hand off to `$ac-execute`.

Hard rules:

- Do not implement feature or document changes in this skill.
- Do not hand off if Contract fields are incomplete.
- Do not freeze generic placeholders or non-existent repo paths as final scope.
