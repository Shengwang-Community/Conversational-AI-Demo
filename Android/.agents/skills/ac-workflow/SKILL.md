---
name: ac-workflow
description: Deliver Android features, fixes, refactors, docs, or workflow changes in this ConvoAI repo with risk-based planning and targeted validation. Use when Codex must modify Android files or independently verify an Android delivery.
---

# Android Delivery Workflow

Deliver the requested Android outcome end to end. Read `Android/AGENTS.md` and the relevant implementation before choosing a path.

## Choose A Profile

- Use `Direct` for a low-risk, local change with clear acceptance criteria and no UI, shared-contract, build, permission, migration, compatibility, security, or device risk.
- Use `Standard` by default. Implement with focused tests, then perform a separate diff and acceptance pass.
- Use `Full` when the change crosses modules or system boundaries, affects UI/UX, shared APIs, configuration, build files, permissions, devices, RTC/RTM/subtitles, migration, compatibility, or security.

Upgrade when exploration reveals more risk. Do not create repository task-state files for any profile.

## Execute

1. Ground the task in the requirement, current diff, call sites, tests, and `ARCHITECTURE.md` when relevant.
2. State the outcome, in-scope files, hard constraints, acceptance criteria, and missing external inputs. Keep this proportional to the task.
3. Implement the smallest coherent change. Preserve existing patterns and unrelated user edits.
4. Add or update focused tests for changed logic and regressions.
5. Run the narrowest checks that prove the acceptance criteria. Expand only when the affected boundary requires it.
6. Review the resulting diff for behavior, edge cases, lifecycle/threading, privacy, and requirement coverage.
7. Report delivered behavior, changed files, exact checks and results, and unresolved gaps.

When invoked by the repository release runner, also return the configured role-result JSON with `files_changed`, `outputs.covered_criteria`, validation evidence, findings, and artifact hashes. Only cite Product-approved gaps through `accepted_gap_refs`; never approve a gap locally.

## Validation Ladder

- Docs/Skill only: reference, terminology, command, and diff checks.
- Logic/API: focused unit tests plus affected-module Kotlin/Java compile.
- UI: affected build plus runtime inspection of relevant states and interactions when an emulator/device is available.
- Shared/build/config/permission/device changes: add affected consumer, variant, lint, integration, or device checks as justified by risk.

Do not claim passed when a required executable check is blocked. Return the blocker and the exact missing evidence.

## Delegation

Stay single-Agent unless the user or parent orchestrator explicitly authorizes delegation. When authorized, delegate only independent read-heavy exploration, test execution, or review; keep implementation ownership and final synthesis unambiguous.

## Boundaries

- Do not commit or push unless explicitly requested.
- Do not invent backend values, credentials, assets, or production contracts.
- Do not replace focused proof with default full-repository builds.
- Do not treat platform self-report as independent acceptance when the selected profile requires a reviewer.
