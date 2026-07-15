---
name: convoai-ios-workflow
description: Deliver iOS features, fixes, refactors, docs, or UI changes in this ConvoAI repo with focused tests and runtime acceptance. Use when Codex must modify or independently verify files under iOS.
---

# ConvoAI iOS Delivery

Deliver the requested outcome end to end. Read `iOS/AGENTS.md`, the requirement/design references, and the relevant current implementation first.

## Choose A Profile

- Use `Direct` for a low-risk, local task with clear acceptance criteria and no UI, shared API, build, device, migration, compatibility, security, or external-contract risk.
- Use `Standard` by default. Implement with focused validation, then perform an independent diff and acceptance pass.
- Use `Full` for cross-module/API work, UI/interaction, concurrency/lifecycle, RTC/RTM, permissions/devices, Pods/project/scheme changes, migration, compatibility, security, or uncertain external contracts.

Plan in proportion to the task. Keep one coherent outcome in flight, but do not split a small task into artificial feature items.

## Execute

1. Define the outcome, scope, constraints, acceptance criteria, validation mode (`logic`, `ui`, `mixed`, or `docs`), and missing inputs.
2. Inspect call sites, tests, ownership, threading/lifecycle, and existing design patterns.
3. Implement the smallest coherent change and preserve unrelated user work.
4. Add or update focused UT for logic. Keep mocks and test fixtures outside production behavior.
5. Run the validation required by the mode and risk.
6. Review the final diff against every acceptance criterion and close findings.
7. Report changed files, exact evidence, residual gaps, and terminal status.

When invoked by the repository release runner, return its role-result JSON with `files_changed`, `outputs.covered_criteria`, validation evidence, findings, and artifact hashes. Only cite Product-approved exceptions through `accepted_gap_refs`.

## Logic Validation

- Prefer the narrowest test in `Agent-cnTests` that covers the behavior.
- Prefer XcodeBuildMCP test tools when available; otherwise use the repository helpers or `xcodebuild test` through `Agent.xcworkspace` and `Agent-cn`.
- Read `references/ios_logic_ut.md` when choosing preflight, build reuse, simulator, architecture, or retry commands.
- A logic task passes only when the agreed focused UT executes successfully. Build-only or static review is insufficient.
- Allow one targeted environment retry for workspace selection, simulator boot, or known simulator architecture linkage. Real compile/assertion failures return `failed`.

## UI Validation

When a runnable simulator/device environment exists, UI or mixed tasks require runtime evidence:

1. Build and run the affected app/scheme, preferably with XcodeBuildMCP.
2. Inspect the rendered UI hierarchy and required loading/empty/error/success states.
3. Exercise the key interaction or navigation path.
4. Capture screenshots and relevant logs as evidence.

If XcodeBuildMCP is unavailable, use equivalent local Xcode/Simulator tooling when it can provide the same evidence. If no runnable environment exists, return `blocked` or an approved gap. Never pass UI from static inspection alone.

## Missing Dependencies

- Do not invent endpoint values, credentials, assets, server responses, or product decisions.
- Use a reversible mock/fixture only when the requirement permits it and make replacement boundaries explicit.
- Do not add production TODO markers merely to satisfy workflow progress. Report the missing input and stop when it prevents a coherent implementation.

## Delegation

Stay single-Agent unless the user or parent orchestrator explicitly requests delegation. When authorized, use separate agents only for independent implementation, test execution, UI inspection, or review. Read `references/contracts.md` for the minimal handoff contract.

## Completion

For implementation requests, return `passed` only when the requested behavior is implemented and every required executable gate has evidence. A completed plan or static scope analysis is not implementation `passed`; label it as a proposal and state that delivery remains unverified. Otherwise return `failed` or `blocked`. Include exact commands and results, whether artifacts were rebuilt or reused, focused test outcomes, and any xcresult/log/screenshot paths. Do not commit or push unless explicitly requested.
