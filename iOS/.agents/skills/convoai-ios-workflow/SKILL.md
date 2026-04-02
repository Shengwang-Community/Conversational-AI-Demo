---
name: convoai-ios-workflow
description: Workflow for implementing, modifying, fixing, or completing iOS requirements in this ConvoAI repo. Logic tasks are UT-first and UI tasks hand visual acceptance to QA. Only spawn the developer+tester multi-agent loop when the user explicitly asks for closed-loop workflow, delegation, or multiple agents.
---

# ConvoAI iOS Workflow

## Overview

This skill may trigger for normal iOS implementation requests such as “帮我实现 xxx 需求”, “帮我修改 xxx 功能”, or “修复这个 iOS 问题”.

When it triggers, choose the execution mode like this:
- If the user explicitly asks for closed-loop workflow, delegation, or multiple agents, keep the main thread as the controller, spawn one developer agent and one tester agent, and drive a loop of implement -> validate -> fix until the tester returns `passed` or the loop blocks.
- If the user does not explicitly authorize sub-agents, stay in single-agent mode and use the same validation rules from this skill, but do not spawn developer/tester sub-agents.

Validation mode is task-dependent:
- Logic/data/API/storage/parsing tasks are UT-first. The developer should add or update relevant unit tests, and the tester should run the agreed UT command. Passing UT is sufficient for `passed`.
- UI tasks do not require smoke checks or simulator walkthroughs by default. QA owns UI acceptance. The tester may run cheap automated checks, but must not block on missing smoke checks.
- Docs-only tasks may use static review only.

## When To Use

Use this skill when all of the following are true:
- The user asks to implement, modify, fix, complete, or deliver an iOS requirement in this repo. This includes requests like “帮我实现 xxx 需求”.
- The task is in this repo, especially under `Scenes/ConvoAI`, `ConversationalAIAPI`, or adjacent iOS app code.
- The task benefits from repeated development and validation rounds.

Multi-agent execution is allowed only when the user explicitly asks for multiple agents, delegation, or a closed-loop dev/test workflow.

Do not use this skill for pure casual chat or non-iOS work in other repos.

## Controller Workflow

1. Ground locally first.
   Read the requirement, inspect likely files, and identify acceptance criteria before spawning anything.
2. Freeze the loop contract.
   Decide the validation mode, target files, allowed commands, validation commands, the primary UT command for `logic` work, any retry/fallback commands, and `max_rounds` up front. Default to `max_rounds = 3`.
3. Spawn the developer agent.
   Prefer narrow-context delegation. If thread history is large or noisy, do not blindly fork the whole thread; pass only the task, acceptance criteria, owned files, and the relevant current file paths. Include test files for logic tasks. Tell the developer it is not alone in the codebase and must not revert unrelated edits.
4. Spawn the tester agent.
   Prefer narrow-context delegation here too. Pass the acceptance criteria, changed files, and the exact UT command rather than full history when possible. Keep the tester read-mostly: it may run checks and do review, but it should not edit production files.
5. Confirm the developer result exists in the shared workspace.
   Before sending work to the tester, verify that the expected files actually changed in the shared workspace with `git diff --name-only` or equivalent. Do not let the tester validate a stale tree.
6. Run the loop.
   Wait for the developer result, send the result and acceptance criteria to the tester, and only treat the task as complete when the tester returns `passed`.
   For logic tasks, a `passed` result should include the agreed UT command and a successful UT result. A plain build is not a substitute for UT. For UI tasks, do not require smoke-check evidence unless the user explicitly asks for it.
7. On failure, forward findings verbatim.
   If the tester returns `failed`, pass `failures`, `logs_summary`, and `fix_suggestions` back to the developer and start the next round.
8. On blockage, classify it.
   Distinguish between environment blockage and code blockage. For logic tasks, if the agreed UT command is blocked by environment, require the tester to do the static pass and return `blocked`, not `passed`. For UI tasks, do not invent a smoke-check blocker; hand off UI verification to QA in the final summary.

## Task Classification

This skill is iOS-only. Before validation, the controller should classify the validation mode for the current iOS task.

Validation mode:
- `logic` for parsing, callbacks, storage, caching, managers, reducers, state machines, API contracts, and non-visual business logic
- `ui` for layout, styling, copy, animation, view hierarchy, navigation presentation, and other changes whose final acceptance belongs to QA
- `docs` for documentation-only work
- `mixed` when both logic and UI change together; logic portions still need UT

## Default Roles

### Developer agent

- Owns production code and any required demo wiring.
- For `logic` tasks, owns relevant unit test additions or updates alongside production code.
- If the repo has no suitable app-owned unit test target for a `logic` task, owns creating or extending the nearest unit-test target needed to run focused UT.
- May update docs only when they are part of the requested delivery.
- Must return the JSON contract from [contracts.md](references/contracts.md).

### Tester agent

- Owns validation only: tests, static checks, review, and acceptance decisions.
- Must not modify production files.
- For `logic` tasks, must run the agreed UT command and use UT as the primary acceptance gate.
- Must not replace missing or failing logic UT with static review.
- For `ui` tasks, must not require smoke checks or simulator walkthroughs unless the user explicitly asks for them.
- Must return the JSON contract from [contracts.md](references/contracts.md).

### Controller agent

- Owns scoping, agent setup, loop control, and final summary.
- Decides whether a tester result is actionable, blocked, or terminal.

## Repo Defaults

When the task is in this repo, prefer this default scope first:
- `iOS/Scenes/ConvoAI/ConvoAI/ConvoAI/Classes/ConversationalAIAPI`
- `iOS/Scenes/ConvoAI/ConvoAI/ConvoAI/Classes/Main/Chat`
- `iOS/Scenes/ConvoAI/ConvoAI/ConvoAI/Classes/Main/Chat/SIP`
- `iOS/*Tests` or adjacent test targets when the task is `logic`
- `iOS/Agent.xcodeproj/project.pbxproj`
- `.gitleaks.toml` only if commit hooks or staged-file validation are part of the task

Common validation commands in this repo:
- `git diff --stat`
- `git diff --name-only`
- `git diff -- <paths>`
- `rg` for call sites and protocol conformances
- `XcodeBuildMCP` test tools when available for iOS UT execution
- `xcodebuild test ...` for UT execution
- `xcodebuild build ...` only when a cheap non-UI compile check is useful, and never as a substitute for UT on `logic` tasks
- `gitleaks protect --config=.gitleaks.toml --staged --verbose` when staged content changed and commitability matters
- `scripts/preflight_ios_logic_ut.sh` for workspace/scheme/simulator preflight
- `scripts/run_ios_logic_ut.sh` for focused logic UT execution

### iOS Logic UT Defaults

For `iOS` + `logic`, prefer one focused UT command over broad build validation and default to the workspace entrypoint for this repo.

Read [ios_logic_ut.md](references/ios_logic_ut.md) when you need the concrete preflight checklist, command templates, and retry policy.

Use the helper scripts when helpful:
- Preflight:
  - `scripts/preflight_ios_logic_ut.sh Agent.xcworkspace Agent.xcodeproj Agent-cn Agent.xcodeproj/xcshareddata/xcschemes/Agent-cn.xcscheme`
- Run focused UT:
  - `scripts/run_ios_logic_ut.sh Agent.xcworkspace Agent-cn SIMULATOR_UUID YourLogicTestsTarget/YourTestClass`

Selection rules:
- Prefer the narrowest UT command that still covers the acceptance criteria.
- If the change is localized, default to `-only-testing`.
- If a new unit test target or test plan is introduced, switch the command template to use that target or `-testPlan`.
- If there is no suitable app-owned unit test target yet, the developer should add one or extend the nearest existing unit-test target as part of the task. Absence of a test target is not a reason to skip UT.

If the agreed automated validation command is blocked by local simulator, signing, or dependency issues, the tester should still perform:
- API compatibility review
- delegate and threading review
- changed-file regression review
- documentation consistency review

Suggested validation ladder:
1. Pick the validation mode first.
2. For `logic`, require targeted UT. Developer adds or updates UT, tester runs UT, and green UT is sufficient for `passed`.
3. If no suitable unit-test target exists for `logic`, create or extend one first, then run UT.
4. For `ui`, do not require smoke checks. Run cheap automated checks only if helpful, and hand UI acceptance to QA.
5. For `docs`, use static review only.
6. Before declaring `blocked`, spend one retry on obvious test-environment fixes such as workspace entry, scheme test wiring, booting the chosen simulator, or an `x86_64` fallback when arm64 simulator linkage is the only blocker.
7. If the agreed automated command is still blocked after those focused retries, return `blocked` plus static findings and the exact manual verification still needed.

iOS validation defaults:
- `logic`: Prefer `XcodeBuildMCP` test tools when available. Fallback to `xcodebuild test`.
- `ui`: No smoke check by default. QA owns final UI validation.

## Guardrails

- Never let the developer and tester edit overlapping production files.
- Never let the tester silently change the acceptance bar.
- Never close the loop on a developer self-report alone.
- Never let the tester validate before the controller confirms the shared workspace actually contains the developer's changes.
- Never pass a `logic` task without running the agreed UT command.
- Never treat `xcodebuild build` or any plain compile check as sufficient validation for a `logic` task.
- Never replace missing logic UT with static review.
- Never waive UT just because the repo currently lacks a suitable app-owned test target.
- Never default to `Agent.xcodeproj` for UT when `Agent.xcworkspace` is available and required for dependency resolution.
- Never require a smoke check for a `ui` task unless the user explicitly asks for one.
- Never treat a `logic` task `blocked` result as equivalent to `passed`.
- Do not push, cherry-pick, or modify remotes unless the user explicitly asks.
- Preserve user changes and unrelated dirty worktrees.

## Output Requirements

- Developer output must be machine-checkable and list changed files.
- Tester output must clearly say `passed`, `failed`, or `blocked`, and include the validation mode and whether validation was static-only or executable.
- Final controller output should summarize:
  - delivered behavior
  - changed files
  - validation mode(s)
  - validation performed
  - residual risks or manual follow-up

See [contracts.md](references/contracts.md) for the exact JSON contracts and prompt templates.
