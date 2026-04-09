---
name: ac-workflow
description: Workflow entrypoint for feat/fix/refactor/chore/docs/continue tasks in this Android repo. Use when the user asks to change code, AGENTS.md, .agents/skills, docs templates, or resume an unfinished PROJECT_STATE.md.
---

1. Call `$ac-memory` first to ensure `PROJECT_STATE.md` exists, is valid, and has a fresh `[STATE]` anchor.
2. Restore or initialize workflow context:
- identify task type (`feat` / `fix` / `refactor` / `chore` / `docs`)
- determine whether this is a new task or `continue`
- read current `PLAN_FROZEN` / `CURRENT_ROLE` / `WORKFLOW_STATUS`
- only resume automatically when `WORKFLOW_STATUS` is not `completed`
3. Determine route using the AGENTS risk score:
- `single` for low-risk work: run minimal `ac-plan` then `ac-execute` responsibilities in the same thread, do not edit files before the Contract is written and `PLAN_FROZEN=true`, and after execution perform summary closeout by writing `CURRENT_ROLE: single` and `WORKFLOW_STATUS: completed`
- `single + reviewer` when review must be forced: complete the same collapsed planning/execution path, but hand off to `$ac-review` instead of performing local summary closeout
- `planner -> executor -> reviewer` for multi-file, high-risk, or workflow-rule changes
4. Echo the exact `[STATE] PROJECT_STATE.md：已检查` or `[STATE] PROJECT_STATE.md：已更新` line in the current user-facing reply, then emit the standard workflow progress display and keep it aligned with the real phase in `PROJECT_STATE.md`.
5. For docs / skills / templates tasks, ensure the Contract uses consistency checks instead of default `gradlew` commands unless code or build files are touched.
6. On phase or status change, update `PROJECT_STATE.md` before handoff.
7. On `continue`, long-running tasks, or context risk, trigger the forced wrap-up pattern:
- pause work
- set `WORKFLOW_STATUS: blocked`
- refresh `PROJECT_STATE.md`
- echo the updated `[STATE]` line
- output completed work, remaining work, and the next resume hint

Outputs:

- valid `PROJECT_STATE.md`
- active route (`single`, `single + reviewer`, or `planner -> executor -> reviewer`)
- current phase and `WORKFLOW_STATUS` aligned across user-facing output and state file

Hard rules:

- Always use `$ac-memory` before role routing.
- Do not replace planner / executor / reviewer responsibilities; orchestrate them, and collapse them only when `single` is explicitly selected.
- Do not leave a finished `single` task in `CURRENT_ROLE: executor` or `WORKFLOW_STATUS: active`.
- Do not treat docs-only file changes as general chat once workflow assets are being edited.
- Do not auto-resume a `WORKFLOW_STATUS: completed` task as `continue`.
- Keep user-facing workflow progress and `[STATE]` echo aligned with actual state in `PROJECT_STATE.md`.
