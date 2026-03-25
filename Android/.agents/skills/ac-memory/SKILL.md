---
name: ac-memory
description: Create, repair, and refresh PROJECT_STATE.md for workflow and continue tasks. Use before planner/executor/reviewer work, or whenever Top 3, decisions, Evidence, Gaps, role, or freeze state changes.
---

1. Ensure `PROJECT_STATE.md` exists; if missing, create it from `docs/PROJECT_STATE_TEMPLATE.md`.
2. Validate required header fields:
- `PLAN_FROZEN`
- `CURRENT_ROLE`
3. Validate required sections exist:
- `目标`
- `下一步 Top 3`
- `阻塞项`
- `关键决策索引（最近 3 条）`
- `关键决策日志（全量追加，不覆盖历史）`
- `验收证据（Evidence）`
- `未验证清单（Gaps）`
- `提交计划`
- `Execution Contract`
4. Repair missing structure in place while preserving existing history and user-written details.
5. Refresh a visible `[STATE] PROJECT_STATE.md：已检查` or `[STATE] PROJECT_STATE.md：已更新` anchor whenever workflow starts, continues, or changes phase.
6. When todo items, decisions, Evidence, Gaps, or role/freeze state change, update the relevant blocks before control returns to the caller.
7. For docs-only tasks, allow `Checks` / `Evidence` to record consistency review instead of pretending code builds ran.

Outputs:

- complete `PROJECT_STATE.md` structure
- current `[STATE]` anchor
- repaired state ready for planning / execution / review

Hard rules:

- Treat `PROJECT_STATE.md` as the current local memory backend.
- Do not continue planner / executor / reviewer work while required structure is missing.
- Preserve existing history in decision logs; append instead of overwriting.
- Never leave stale `CURRENT_ROLE` or `PLAN_FROZEN` values after a phase change.
