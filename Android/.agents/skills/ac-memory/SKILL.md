---
name: ac-memory
description: Create, repair, and refresh `.agents/state/INDEX.md` plus a caller-selected task state file for workflow and continue tasks. Use after `ac-workflow` has resolved whether work should bind a new task or a specific continue target, or whenever Top 3, decisions, Evidence, Gaps, Review Findings closure, role, or freeze state changes.
---

1. Ensure `.agents/state/INDEX.md` exists; if missing, create it from `docs/STATE_INDEX_TEMPLATE.md`.
2. Require the caller to resolve the target binding first:
- new task: explicit `TASK_ID` and `TASK_TITLE`
- continue: explicit `task-id` or exact `TASK_TITLE`
3. Ensure the selected task state file exists under `.agents/state/tasks/`; if missing for a caller-confirmed new workflow task, create it from `docs/TASK_STATE_TEMPLATE.md`.
4. Validate required header fields:
- `TASK_ID`
- `TASK_TITLE`
- `TASK_TYPE`
- `PLAN_FROZEN`
- `CURRENT_ROLE`
- `WORKFLOW_STATUS`
- `STARTED_AT`
- `LAST_UPDATED_AT`
5. Validate required sections exist:
- `目标`
- `下一步 Top 3`
- `阻塞项`
- `关键决策索引（最近 3 条）`
- `关键决策日志（全量追加，不覆盖历史）`
- `验收证据（Evidence）`
- `未验证清单（Gaps）`
- `Review Findings（闭环）`
- `提交计划`
- `Execution Contract`
6. Repair missing structure in place while preserving existing history and user-written details.
7. Sync `.agents/state/INDEX.md` with `CURRENT_TASK` plus `Active / Blocked / Completed` summaries, using the stable entry format `task-id | TASK_TITLE | task-type | role | status`.
8. Return a concise state summary such as `[STATE] <task-id> | <role> | <status> | 已检查/已更新` for the caller to echo when helpful.
9. When todo items, decisions, Evidence, Gaps, Review Findings closure, or role/freeze/status change, update the relevant blocks before control returns to the caller.
10. For docs-only tasks, allow `Checks` / `Evidence` to record consistency review instead of pretending code builds ran.

Outputs:

- complete active task state structure
- updated `.agents/state/INDEX.md`
- current state summary
- repaired state ready for planning / execution / review

Hard rules:

- Treat the active task state file as the current workflow source of truth, with `.agents/state/INDEX.md` as the task registry.
- Do not infer a continue target from partial wording when multiple unfinished tasks could match; require the caller to resolve `TASK_TITLE` or `task-id` first.
- Do not create a new task file until the caller has explicitly chosen `new task` instead of `continue`.
- Do not continue planner / executor / reviewer work while required structure is missing.
- Preserve existing history in decision logs; append instead of overwriting.
- Never leave stale `CURRENT_ROLE`, `PLAN_FROZEN`, or `WORKFLOW_STATUS` values after a phase change.
