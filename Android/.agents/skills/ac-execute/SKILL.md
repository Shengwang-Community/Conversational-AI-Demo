---
name: ac-execute
description: Execute only the frozen Execution Contract for code or docs tasks, collect evidence, and stop on scope drift. Use when PLAN_FROZEN=true and the Contract's files/checks are complete.
---

1. Use `$ac-memory` to validate `PROJECT_STATE.md` structure before execution.
2. Verify `PLAN_FROZEN=true` and `Execution Contract` completeness.
3. Set `CURRENT_ROLE: executor` and keep `WORKFLOW_STATUS: active`.
4. Change only files listed in `Files to change`.
5. Follow `Steps` exactly:
- code tasks run the declared `gradlew` / device checks
- docs / skills / templates tasks run the declared consistency checks
6. When the task changes shared workflow assets, update the coupled documents together so terminology and routing stay in sync.
7. Record results in `验收证据（Evidence）` and update Top 3 completion.
8. If the route is `single + reviewer` or `planner -> executor -> reviewer`, hand off to `$ac-review`.
9. If the route is pure `single`, return control to `$ac-workflow` for summary closeout (`CURRENT_ROLE: single`, `WORKFLOW_STATUS: completed`).

Unfreeze fallback (mandatory):

1. Stop execution immediately when new design, scope, or file impact appears.
2. Append a decision log entry with date, decision, and impact.
3. Set `PLAN_FROZEN: false`, `CURRENT_ROLE: planner`, and `WORKFLOW_STATUS: active`.
4. Return to `$ac-plan` for a new Contract.

Hard rules:

- Do not add design alternatives during execution.
- Do not edit files outside the Contract scope.
- Do not claim checks ran if they did not.
