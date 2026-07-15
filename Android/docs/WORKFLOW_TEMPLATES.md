# Android Workflow Templates

Use these templates to define completion, not to create repository plan or state files. Read the requirement, current diff, call sites, tests, and relevant architecture before selecting the smallest profile that can prove the outcome.

## Profile Selection

| Profile | Use when | Minimum acceptance |
|---|---|---|
| Direct | Local, low-risk, and clearly bounded | Focused affected test, narrow compile, and diff review |
| Standard | Ordinary feature or fix; default | Direct evidence plus independent acceptance review |
| Full | Cross-module, UI/UX, shared contract, build/configuration, permission, migration, compatibility, security, device, RTC/RTM, SIP, transcript, or uncertain external contract | Explicit design and risk, expanded tests, runtime evidence where required, and independent acceptance |

A task that needs an HLD or UI/interaction design is Full. A small file count does not make a task low risk.

## Completion Contract

- Outcome: the user-observable result.
- Scope: allowed modules, files, interfaces, and behavior.
- Constraints: compatibility, permissions, threading, lifecycle, privacy, and external boundaries.
- Acceptance criteria: individually decidable statements, not "works correctly."
- Evidence: commands, tests, screenshots, logs, or manual paths actually completed in this run.
- Gaps: missing environment, device, server, design, production contract, or runtime evidence.

## Feature

1. Trace the existing entry, state, network or SDK, and UI call path.
2. Put backend fields, defaults, error states, and fallback behavior in the acceptance criteria.
3. Implement the smallest coherent change in the owning module and update consumers and tests.
4. Run focused tests and the affected compile task; add runtime evidence for UI, media, permission, or device behavior.
5. For Standard or Full, perform an independent diff and requirement-coverage review.

## Fix

1. Bound the symptom and root cause with logs, a test, or a concrete code path.
2. Add the smallest regression test first, or explain why automation is not feasible.
3. Fix the root cause without unrelated refactoring.
4. Validate the failure path, adjacent branches, and the original success path.
5. When reproduction or an external input is unavailable, report incomplete acceptance instead of claiming the issue is fixed.

## Refactor

1. Define the behavior that must remain unchanged and list affected consumers.
2. Establish a baseline with existing tests; add coverage for critical behavior when needed.
3. Keep each step compilable and avoid changing a public contract and its internal implementation at the same time.
4. Validate affected modules and consumers.

## UI

1. Extract layout, copy, loading, empty, error, success, interaction, accessibility, and responsive requirements from the product source and Figma.
2. Preserve the existing Activity, Fragment, ViewBinding, and design-system patterns.
3. Build the affected variant and, when possible, inspect required states and interactions on an emulator or device with screenshots.
4. Without the required runtime environment, report `blocked` or a Product-approved gap. Static inspection alone cannot pass UI acceptance.

## Documentation or Skill

1. Keep durable engineering facts, domain constraints, and executable acceptance rules.
2. Use English for repository-maintained Android AI and workflow documentation.
3. Check paths, commands, Skill frontmatter, entrypoint references, and terminology.
4. Remove dangling references, duplicated policy, and process scaffolding that the model can derive.
5. Do not run unrelated full Android builds.

## Validation Selection

- Use `./gradlew tasks` or the target module's `tasks --all` to confirm the real task name when uncertain.
- For logic, prefer a focused `:<module>:test... --tests '<TestClass>'` and the affected `compile...Kotlin` task.
- For shared modules, Gradle, manifests, resources, or dependencies, add affected consumers, variants, assemble, or lint.
- For UI, permissions, BLE, IoT, RTC/RTM, SIP, or transcripts, add emulator, device, or integration evidence as required.
- Record exact commands and results. Never rewrite "not run" as "passed."

## Consistency Checks

Run these from `Android/`. The language scan passes when it returns no matches.

```bash
rg -n 'ac-(plan|execute|review|memory)|TASK_STATE_TEMPLATE|STATE_INDEX_TEMPLATE|PLAN_FROZEN|WORKFLOW_STATUS' \
  AGENTS.md .agents/skills docs --glob '!WORKFLOW_TEMPLATES.md'
rg -n 'Direct|Standard|Full|accepted_gap_refs' AGENTS.md .agents/skills docs
rg -n -P '[\p{Han}]' AGENTS.md ARCHITECTURE.md .agents/skills docs
git diff --check -- AGENTS.md ARCHITECTURE.md .agents/skills docs
```
