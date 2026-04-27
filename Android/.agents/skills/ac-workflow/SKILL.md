---
name: ac-workflow
description: Workflow entrypoint for feat/fix/refactor/chore/docs/continue tasks in this Android repo. Use when the user asks to change code, AGENTS.md, .agents/skills, docs templates, or explicitly resume an unfinished task state under `.agents/state/tasks/`.
---

1. Inspect `.agents/state/INDEX.md` plus unfinished task summaries first; do not bind, select, or create any task state file yet.
2. Resolve workflow context before calling `$ac-memory`:
- identify task type (`feat` / `fix` / `refactor` / `chore` / `docs`)
- determine whether this is a new task or `continue`
- check whether the request is a pure copy-edit exempted by AGENTS; if yes, do not enter workflow state handling
- treat `active` / `blocked` as resumable only when the user explicitly indicates `continue`
- if unfinished task-state files exist but the user intent is a new task, create a new task instead of auto-resuming
- if the user says `continue` and multiple unfinished tasks exist, require `TASK_TITLE` or `task-id` before binding a task
- resolve the target task by explicit `task-id` or by exact `TASK_TITLE`
3. Call `$ac-memory` only after the target task is resolved, so `.agents/state/INDEX.md` and the selected or newly created task state file are valid and ready for routing.
4. Determine route using the AGENTS risk score:
- `single` for low-risk work: run minimal `ac-plan` then `ac-execute` responsibilities in the same thread, do not edit files before the Contract is written and `PLAN_FROZEN=true`, and after execution perform summary closeout by writing `CURRENT_ROLE: single` and `WORKFLOW_STATUS: completed`
- `single + reviewer` when review must be forced: complete the same collapsed planning/execution path, hand off to `$ac-review`, then reclaim control after a pass for final summary closeout
- `planner -> executor -> reviewer` for multi-file, high-risk, or workflow-rule changes; reclaim control after `$ac-review` passes for final summary closeout
- for low-risk work that is not AGENTS copy-edit exempt, prefer `single` unless coupled workflow assets, routing semantics, or shared terminology also change
5. Echo a concise state line such as `[STATE] <task-id> | <role> | <status> | 已检查/已更新` when helpful, then emit the standard workflow progress display and keep it aligned with the real phase in the active task state file.
5.5. When running a low-risk non-copy-edit task, the caller may echo a concise line such as `当前按轻量 workflow 执行`; the workflow progress display may be shortened as long as the active task state remains accurate.
6. For docs / skills / templates tasks, ensure the Contract uses consistency checks instead of default `gradlew` commands unless code or build files are touched.
7. On phase or status change, update the active task state file and `.agents/state/INDEX.md` before handoff.
8. On `continue`, long-running tasks, or context risk, trigger the forced wrap-up pattern:
- pause work
- set `WORKFLOW_STATUS: blocked`
- refresh the active task state file and `.agents/state/INDEX.md`
- echo the updated `[STATE]` line when helpful
- output completed work, remaining work, and the next resume hint with both `TASK_TITLE` and `task-id`
9. Summary closeout ownership:
- `$ac-workflow` is the only owner of final `📝 总结`
- after `$ac-review` passes, echo the final `[STATE]` line when helpful and output the summary in the same thread
- for reviewed routes, keep `CURRENT_ROLE: reviewer` and `WORKFLOW_STATUS: completed`; do not rewrite reviewed tasks to `single`

Outputs:

- valid `.agents/state/INDEX.md`
- valid selected or newly created active task state file
- active route (`single`, `single + reviewer`, or `planner -> executor -> reviewer`)
- current phase and `WORKFLOW_STATUS` aligned across user-facing output and state file

Hard rules:

- Always resolve `new task` versus `continue`, plus the target `TASK_TITLE` / `task-id`, before calling `$ac-memory` in a way that binds or creates a task state file.
- Do not replace planner / executor / reviewer responsibilities; orchestrate them, and collapse them only when `single` is explicitly selected.
- Do not create workflow state for AGENTS copy-edit-exempt requests.
- Do not let `$ac-memory` auto-create or auto-select a task while continue intent is unresolved or ambiguous.
- Do not leave a finished `single` task in `CURRENT_ROLE: executor` or `WORKFLOW_STATUS: active`.
- Do not treat docs-only file changes as general chat once workflow assets are being edited.
- Do not auto-resume from `.agents/state/INDEX.md` or `.agents/state/tasks/*.md` without explicit user intent to continue.
- Do not auto-resume a `WORKFLOW_STATUS: completed` task as `continue`.
- Do not leave passed reviewed routes without returning to `$ac-workflow` for final summary closeout.
- Keep user-facing workflow progress and `[STATE]` echo aligned with actual state in the active task state file.
