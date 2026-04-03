# Multi-Agent Contracts

Use these contracts to keep the closed loop deterministic.

## Controller Checklist

Before spawning agents, the controller should lock:
- the ordered feature plan
- the active feature item for this loop
- the validation mode
- the user goal
- acceptance criteria
- target file ownership
- validation commands
- the primary UT command when validation mode is `logic`
- any one-shot retry or fallback commands for obvious iOS test-environment issues
- the UT reporting requirements for the final summary:
  exact UT command(s), per-command result, whether artifacts were rebuilt or reused, test-case details or counts, and `xcresult`/log paths when available
- max rounds

Recommended defaults:
- `max_rounds = 3`
- one active feature item at a time
- developer writes production code only
- tester is read-only for production code
- `logic` tasks require developer-added or updated UT and tester-run UT before `passed`
- executable UT runs must be reported back with full user-visible status, not just a pass/fail label
- `ui` tasks do not require smoke checks; QA owns UI acceptance
- validation commands must match the iOS toolchain used in this repo
- plain build commands do not satisfy `logic` validation on their own
- prefer `Agent.xcworkspace` over `Agent.xcodeproj` for UT when the workspace is available

## Feature Plan Template

Use a small plan object before entering the loop. Keep later items pending until the active one is closed.

```json
[
  {
    "id": "F1",
    "title": "short feature title",
    "goal": "user-visible outcome for this item",
    "validation_mode": "logic|ui|docs|mixed",
    "depends_on": [],
    "owned_files": ["path/to/file"],
    "acceptance_criteria": ["specific, testable outcome"],
    "validation_commands": ["exact command or method"],
    "closure_signal": "what must be true before moving to the next item",
    "status": "active|pending"
  }
]
```

Plan rules:
- split the requirement into independently closable items
- keep dependent downstream work in later items
- keep exactly one `active` item
- do not promote the next item until the current item is validated as closed

## Developer Prompt Template

```text
You are the developer agent for this repo.

Task:
- implement the current active feature item only

Feature plan context:
- current item id/title: [paste]
- current item goal: [paste]
- dependencies already satisfied: [paste]
- later pending items: [paste concise list]

Acceptance criteria:
- [paste criteria for the active feature item only]

Owned files:
- [paste paths for the active feature item]

Rules:
- You are not alone in the codebase.
- Do not revert unrelated changes.
- Do not edit files outside your ownership.
- Do not pre-implement later planned items unless a tiny supporting change is required to close the active item.
- If validation mode is `logic`, add or update relevant unit tests in your owned files.
- If validation mode is `logic` and there is no suitable app-owned unit test target, create or extend one as part of the task.
- If validation mode is `logic` and the test target is new, update any shared scheme wiring needed for the agreed UT command to run.
- If tester findings are provided, fix only those findings plus required follow-on changes.

Return JSON only:
{
  "status": "done|blocked",
  "changed_files": ["..."],
  "suggested_validation_commands": ["..."],
  "summary": "...",
  "self_check": "...",
  "known_risks": ["..."]
}
```

## Tester Prompt Template

```text
You are the tester agent for this repo.

Goal:
- validate whether the developer result closes the current active feature item

Inputs:
- feature plan summary
- current feature item id/title
- validation mode
- task summary
- acceptance criteria
- changed files
- relevant diff or commit
- validation commands to try

Rules:
- Do not modify production files.
- Validate only the active feature item; later pending items are not grounds for failure.
- If validation mode is `logic`, run the agreed UT command and use it as the primary gate.
- Do not treat a plain build or compile-only command as sufficient for `logic` validation.
- Do not replace missing or failing logic UT with static review.
- For iOS logic, prefer `XcodeBuildMCP` test tools when available, then fall back to `xcodebuild test`.
- If validation mode is `ui`, do not require smoke checks or simulator walkthroughs unless the user explicitly asks for them.
- Before returning `blocked`, spend one focused retry on obvious iOS test-environment fixes that are safe and local to validation:
  - switch from `-project` to `-workspace` when dependency resolution is the issue
  - boot the chosen simulator if it is not booted
  - retry once with an `x86_64` simulator destination if arm64 simulator linkage fails on a legacy dependency
- If the agreed automated command fails due to environment, continue with static review and return `blocked` instead of `passed` unless the task is `docs` or the controller explicitly scoped UI acceptance to QA.
- Be specific; do not say only "failed".
- When executable UT runs, collect the full UT state needed by the final user-facing summary:
  - exact UT command(s)
  - per-command result (`passed|failed|blocked`)
  - whether build artifacts were rebuilt or reused
  - concrete test-case details when available
  - `xcresult` or log path when available

Return JSON only:
{
  "status": "passed|failed|blocked",
  "validation_mode": "logic|ui|docs|mixed",
  "validation_level": "executable|static-only|blocked-by-env",
  "commands": ["..."],
  "failures": ["..."],
  "logs_summary": "...",
  "fix_suggestions": ["..."],
  "ut_status": {
    "commands": [
      {
        "command": "...",
        "result": "passed|failed|blocked",
        "artifacts": "rebuilt|reused|unknown",
        "summary": "...",
        "passed_tests": ["..."],
        "failed_tests": ["..."],
        "skipped_tests": ["..."],
        "xcresult_path": "...",
        "log_path": "..."
      }
    ]
  }
}
```

## Loop Policy

If tester returns:
- `passed`: controller marks the active item done, summarizes delivery, and only then may activate the next planned item
- `failed`: controller forwards failures verbatim to developer and starts the next round
- `blocked`: controller decides whether there is still a useful static pass; if not, stop and report the blocker without skipping to later items

Controller must also verify the developer result actually exists in the shared workspace before asking the tester to validate. A common guard is `git diff --name-only` scoped to the owned files.

For production code tasks:
- only one feature item may be active in a loop
- `logic` `passed` should mean the agreed UT command succeeded.
- user-facing completion for executable UT must surface the full UT status block, not just "passed"
- `logic` `blocked` should be used when UT execution is required but impossible because of environment or tooling constraints.
- `logic` `failed` should be used for real scheme wiring issues, test-file compile failures, assertion failures, or other actionable code/test defects.
- if no suitable unit-test target exists for a `logic` task, the expected path is to add or extend one, not to waive UT
- `ui` `passed` does not require a smoke check; QA owns UI acceptance unless the user explicitly asks for runtime validation.
- automated validation should be chosen from the iOS toolchain already used in this repo

## ConvoAI-Specific Review Focus

When validating ConvoAI API or iOS integration work, check:
- protocol compatibility and optional callbacks
- delegate dispatching on the main thread
- RTM or Presence parsing reuse and fallback logic
- subscription-time state recovery
- demo integration parity
- README and code consistency
- commit hook side effects if `.gitleaks.toml` or staged docs changed

For ConvoAI tasks, prefer this validation order:
1. `logic`: targeted UT command
2. if no suitable unit-test target exists, add or extend one, then run UT
3. if the first UT attempt fails for an obvious local iOS test-environment reason, spend one focused retry on workspace/simulator/arch correction
4. `ui`: no smoke check by default; focused static scan and QA handoff
5. `docs`: static scan only
6. explicit `blocked` result if the agreed automated validation is still unavailable after those focused retries
