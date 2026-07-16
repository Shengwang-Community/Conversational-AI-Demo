# Android AI Collaboration Guide

This file records durable engineering facts, permission boundaries, and acceptance rules. Let the model derive task-specific steps from the requirement, the live code, and `ac-workflow`. Do not maintain a repository task-state machine.

## Project Facts

- Product: Shengwang Convo AI Demo for Android. The primary UI stack is Android Views with ViewBinding.
- Modules: `app` is the entry shell, `common` is the shared foundation, `scenes:convoai` owns the main product, and `iot` / `bleManager` own device connectivity.
- Build: the app currently has one `china` flavor and requires API 26 or newer. `app`, `common`, and `scenes:convoai` use Java 17; `iot` and `bleManager` use Java 11.
- Configuration: `gradle.properties` is the main local configuration source. Never commit real App IDs, certificates, tokens, credentials, or private source content.
- Architecture: use `ARCHITECTURE.md` for module ownership, runtime flows, contract boundaries, and high-risk areas. Do not duplicate those details here.

## Working Agreement

- Recover context from the user outcome, the current diff, relevant implementation, tests, and real call sites.
- Use `.agents/skills/ac-workflow/SKILL.md` for implementation tasks. Small, low-risk work may proceed directly without local plan or state files.
- Stay single-Agent by default. Delegate only when the user or parent orchestrator explicitly authorizes it and the work splits into independent units.
- Preserve existing user changes. Do not reset, overwrite, or opportunistically refactor unrelated code.
- Do not commit, push, cherry-pick, or perform remote writes unless explicitly requested.
- When a requirement, design, backend contract, or device input is missing, use a replaceable mock where authorized or report a concrete gap. Never invent credentials, URLs, assets, or production data.
- When invoked by the repository release runner, report platform gaps but do not approve them. Reference only Product-approved gap IDs through `accepted_gap_refs`.

## Delivery Profiles

- `Direct`: a local, low-risk change with clear boundaries. Run focused tests and the narrowest affected compile check.
- `Standard`: the default for ordinary features and fixes. Add an independent diff and acceptance pass to Direct validation.
- `Full`: work involving modules or system boundaries, UI/UX, shared contracts, permissions, devices, build/configuration, migration, compatibility, security, RTC/RTM/subtitles, or uncertain external contracts. Clarify design and risk before implementation, then broaden validation.

Do not select a profile by file count. Upgrade when exploration reveals a new boundary or risk; downgrade only with evidence.

## Engineering Constraints

- Keep `app` limited to flavor, manifest, signing, and entry responsibilities. Product logic belongs in its owning feature module.
- Explain consumer impact when changing `common`.
- Treat Agent REST payloads and presets, the published Agent Client Toolkit, the Demo-owned legacy transcript renderer, RTC/RTM, subtitles, Gradle, manifests, and configuration injection as high-risk boundaries.
- Preserve Activity, Fragment, and ViewBinding patterns unless the requirement explicitly calls for Compose or a new architecture.
- For `CAMERA`, `RECORD_AUDIO`, Bluetooth, location, or Wi-Fi, cover request timing, denial, retry, and recovery.
- Mark IoT/BLE, media, and device-dependent behavior as unverified when no suitable device evidence exists.
- Update consumers, focused tests, and adjacent documentation when a shared contract changes.

## Validation

Use the narrowest checks that prove the acceptance criteria. Do not run repository-wide `lint + test + assemble` by default.

- Kotlin or business logic: run the focused test class or target-module tests, then the affected compile task.
- UI: build the affected module or variant; when an emulator or device is available, inspect required states and interactions and retain screenshots or logs.
- Build configuration, manifests, dependencies, resources, or shared modules: include affected variants, consumers, assemble, or lint checks as justified by the boundary.
- IoT/BLE/RTC/RTM/subtitles: add targeted logs, integration checks, or device evidence. Report the missing evidence when the environment is unavailable.
- Documentation or Skills: validate paths, terminology, commands, frontmatter, and dangling references. Do not claim unrelated Android build coverage.

Only fresh evidence can support `passed`. Static inspection cannot replace explicitly required runtime acceptance.

## Review

- Lead a requested review with actionable findings ordered by severity and grounded in file and line references. If there are no findings, state that clearly and report residual test risk.
- For development-integration review, evaluate against declared mocks, backend assumptions, and non-goals. Keep unverified concerns as assumptions or open questions.
- For fix review, verify that the root cause is closed and regression coverage is sufficient.
- Critical or High findings must be `fixed`, `rejected with evidence`, covered by a Product-approved gap, or `blocked` before acceptance can pass.

## Documentation

- Repository-maintained Android AI and workflow documentation must be written in English: `AGENTS.md`, `ARCHITECTURE.md`, `.agents/skills`, and `docs`.
- Product copy, localized resources, source comments, and external requirement text follow their own product or localization rules.
- Keep workflow terminology aligned across the entrypoint, Skill, templates, and review checklist.

## Reference Map

- `ARCHITECTURE.md`: modules, runtime flows, contracts, and high-risk boundaries.
- `.agents/skills/ac-workflow/SKILL.md`: Android delivery and acceptance playbook.
- `docs/WORKFLOW_TEMPLATES.md`: profile and validation guidance by task type.
- `docs/REVIEW_TEMPLATES.md`: review criteria and output contract.
- `docs/DEBUG_WORKFLOW.md`: diagnosis and evidence collection.
- `docs/PR_CHECKLIST.md`: final change checklist.
