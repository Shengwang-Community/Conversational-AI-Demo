---
name: ac-memory
description: Create, repair, and refresh `.agents/state/INDEX.md` plus a caller-selected task state file for workflow and continue tasks. Use after `ac-workflow` has resolved whether work should bind a new task or a specific continue target, or whenever Top 3, decisions, Evidence, Gaps, Review Findings closure, role, or freeze state changes.
---

1. Ensure `.agents/state/INDEX.md` exists; if missing, create it from `docs/STATE_INDEX_TEMPLATE.md`.
2. Require the caller to resolve the target binding first:
- new task: explicit `TASK_ID` and `TASK_TITLE`
- continue: explicit `task-id`, exact `TASK_TITLE`, or a caller-confirmed candidate selected after workflow-side matching
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
9.5. For low-risk non-copy-edit work, allow multiple closely related small edits within the same execution burst to be recorded as one material update, as long as the task state still reflects:
- current Top 3 completion
- new Evidence
- current role / freeze / status
- updated `LAST_UPDATED_AT`
In this context, `same execution burst` means from Contract freeze until the caller's next user-facing reply; do not carry a batched write across turns.
Cap one batched write at `3` declared steps or roughly `50` net changed lines; if the burst exceeds that size, require another state update before the caller finishes.
9.6. For low-risk non-copy-edit work, append `关键决策日志` only when a real scope, wording, routing, or consistency decision was made; do not require artificial decision entries for trivial wording-only edits.
9.7. When a lightweight execution burst touches or nearly touches the batching cap, allow `Evidence` or `Gaps` to record a short threshold observation such as `阈值可接受` / `阈值偏紧` / `阈值偏松`, so later workflow tuning has fresh evidence to reference.
10. For docs-only tasks, allow `Checks` / `Evidence` to record consistency review instead of pretending code builds ran.

Outputs:

- complete active task state structure
- updated `.agents/state/INDEX.md`
- current state summary
- repaired state ready for planning / execution / review

Hard rules:

- Treat the active task state file as the current workflow source of truth, with `.agents/state/INDEX.md` as the task registry.
- Do not infer a continue target from partial wording when multiple unfinished tasks could match; candidate matching may narrow choices, but the caller must still confirm the final `TASK_TITLE` or `task-id`.
- Do not create a new task file until the caller has explicitly chosen `new task` instead of `continue`.
- Do not continue planner / executor / reviewer work while required structure is missing.
- Preserve existing history in decision logs; append instead of overwriting.
- Never leave stale `CURRENT_ROLE`, `PLAN_FROZEN`, or `WORKFLOW_STATUS` values after a phase change.
