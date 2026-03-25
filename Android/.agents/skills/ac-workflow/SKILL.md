---
name: ac-workflow
description: Workflow entrypoint for feat/fix/refactor/chore/docs/continue tasks in this Android repo. Use when the user asks to change code, AGENTS.md, .agents/skills, docs templates, or resume an unfinished PROJECT_STATE.md.
---

1. Call `$ac-memory` first to ensure `PROJECT_STATE.md` exists, is valid, and has a fresh `[STATE]` anchor.
2. Restore or initialize workflow context:
- identify task type (`feat` / `fix` / `refactor` / `chore` / `docs`)
- determine whether this is a new task or `continue`
- read current `PLAN_FROZEN` / `CURRENT_ROLE`
3. Determine route using the AGENTS risk score:
- `single` for low-risk work
- `single + reviewer` when review must be forced
- `planner -> executor -> reviewer` for multi-file, high-risk, or workflow-rule changes
4. Emit the standard workflow progress display and keep it aligned with the real phase in `PROJECT_STATE.md`.
5. For docs / skills / templates tasks, ensure the Contract uses consistency checks instead of default `gradlew` commands unless code or build files are touched.
6. On phase change, update `PROJECT_STATE.md` before handoff.
7. On `continue`, long-running tasks, or context risk, trigger the forced wrap-up pattern:
- pause work
- refresh `PROJECT_STATE.md`
- output completed work, remaining work, and the next resume hint

Outputs:

- valid `PROJECT_STATE.md`
- active route (`single`, `single + reviewer`, or `planner -> executor -> reviewer`)
- current phase aligned across user-facing output and state file

Hard rules:

- Always use `$ac-memory` before role routing.
- Do not replace planner / executor / reviewer responsibilities; orchestrate them.
- Do not treat docs-only file changes as general chat once workflow assets are being edited.
- Keep user-facing workflow progress aligned with actual state in `PROJECT_STATE.md`.
