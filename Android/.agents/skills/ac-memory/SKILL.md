---
name: ac-memory
description: Create, repair, and refresh `.agents/state/INDEX.md` and the active task state file for workflow and continue tasks. Use before planner/executor/reviewer work, or whenever Top 3, decisions, Evidence, Gaps, role, or freeze state changes.
---

1. Ensure `.agents/state/INDEX.md` exists; if missing, create it from `docs/STATE_INDEX_TEMPLATE.md`.
2. Ensure an active task state file exists under `.agents/state/tasks/`; if missing for a new workflow task, create it from `docs/TASK_STATE_TEMPLATE.md`.
3. Validate required header fields:
- `TASK_ID`
- `TASK_TYPE`
- `PLAN_FROZEN`
- `CURRENT_ROLE`
- `WORKFLOW_STATUS`
- `STARTED_AT`
- `LAST_UPDATED_AT`
4. Validate required sections exist:
- `目标`
- `下一步 Top 3`
- `阻塞项`
- `关键决策索引（最近 3 条）`
- `关键决策日志（全量追加，不覆盖历史）`
- `验收证据（Evidence）`
- `未验证清单（Gaps）`
- `提交计划`
- `Execution Contract`
5. Repair missing structure in place while preserving existing history and user-written details.
6. Sync `.agents/state/INDEX.md` with `CURRENT_TASK` plus `Active / Blocked / Completed` summaries.
7. Return a concise state summary such as `[STATE] <task-id> | <role> | <status> | 已检查/已更新` for the caller to echo when helpful.
8. When todo items, decisions, Evidence, Gaps, or role/freeze/status change, update the relevant blocks before control returns to the caller.
9. For docs-only tasks, allow `Checks` / `Evidence` to record consistency review instead of pretending code builds ran.

Outputs:

- complete active task state structure
- updated `.agents/state/INDEX.md`
- current state summary
- repaired state ready for planning / execution / review

Hard rules:

- Treat the active task state file as the current workflow source of truth, with `.agents/state/INDEX.md` as the task registry.
- Do not continue planner / executor / reviewer work while required structure is missing.
- Preserve existing history in decision logs; append instead of overwriting.
- Never leave stale `CURRENT_ROLE`, `PLAN_FROZEN`, or `WORKFLOW_STATUS` values after a phase change.
