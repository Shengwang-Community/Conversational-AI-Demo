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
4. Verify the changed artifacts are internally consistent:
- repo paths and module names match the current project
- docs-only checks were recorded honestly
- skill descriptions still explain what they do and when to use them
5. Update `验收证据（Evidence）` with concrete proof.
6. Update `未验证清单（Gaps）` with residual risks, missing checks, and untested continue/doc workflows.
7. Decide outcome:
- Pass: keep `PLAN_FROZEN=true` and allow summary / submit prep
- Fail: set `PLAN_FROZEN=false` and route back to `$ac-plan`

Hard rules:

- Base conclusions on Contract and evidence only.
- Do not skip Gaps when any verification is missing.
- Do not pass work that still contains known cross-document inconsistencies.
