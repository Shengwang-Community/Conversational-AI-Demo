---
name: ac-review
description: Review frozen-contract execution against Evidence and Gaps for code or docs tasks. Use after ac-execute, or at milestone acceptance gates when workflow assets or implementation need validation.
---

1. Use `$ac-memory` to validate `PROJECT_STATE.md` structure before review.
2. Set `CURRENT_ROLE: reviewer`.
3. Compare actual changes against the Contract:
- Scope
- Forbidden
- Steps
- Checks
4. If the original user request or Contract explicitly matches an exact review trigger, lock review mode before judging findings:
- `开发态联调 review` -> dev-stage integration review
- `问题修复 review` -> fix / regression review
- no trigger -> default code review
5. If the Contract / Evidence / Gaps explicitly describe development-stage assumptions, backend contract premises, local cache policy, or non-goals, review against those boundaries first.
6. Verify the changed artifacts are internally consistent:
- repo paths and module names match the current project
- docs-only checks were recorded honestly
- skill descriptions still explain what they do and when to use them
- for dev-stage integration tasks, unresolved items that depend on unverified backend behavior should be framed as `Gaps` / `assumption` / `open question` unless code or evidence clearly contradicts the declared boundary
7. Update `验收证据（Evidence）` with concrete proof.
8. Update `未验证清单（Gaps）` with residual risks, missing checks, and untested continue/doc workflows.
9. When review reveals repeated mistakes, cross-document drift, or reusable workflow lessons, recommend `$self-improving-agent` after review to write candidate patterns into its own `memory/`.
10. Decide outcome:
- Pass: set `CURRENT_ROLE: reviewer`, set `WORKFLOW_STATUS: completed`, keep `PLAN_FROZEN=true`, then return control to `$ac-workflow` for final summary closeout and final `[STATE]` echo
- Fail: set `CURRENT_ROLE: reviewer`, set `WORKFLOW_STATUS: active`, set `PLAN_FROZEN=false`, and route back to `$ac-plan`

Hard rules:

- Base conclusions on Contract and evidence only.
- Do not skip Gaps when any verification is missing.
- Do not pass work that still contains known cross-document inconsistencies.
- Do not leave `WORKFLOW_STATUS: active` after a pass conclusion.
- Do not require `$self-improving-agent` for pass/fail; it is an optional post-review follow-up.
- Do not treat `$ac-review` as the final summary owner; passed work must return to `$ac-workflow` for `📝 总结`.
- Do not treat development-only cache cleanup, debug placeholders, or declared backend assumptions as confirmed regressions unless release expectations or evidence clearly reject those assumptions.
- Do not switch into dev-stage or fix-review mode from fuzzy wording; only the exact trigger phrase or an explicit Contract record can do that.
