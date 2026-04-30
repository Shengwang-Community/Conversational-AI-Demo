---
name: requesting-code-review
description: Prepare repo-local review requests and required context for the current workflow. Use when completing tasks, implementing major features, or before merging and the work should enter `ac-review`.
---

# Requesting Code Review

Prepare a repo-local review request that feeds the current `ac-review` path with the right Contract, Evidence, and Gaps. In this repository, review should stay inside the existing workflow instead of dispatching external reviewer subagents that do not write back to the active task state file.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After completing a major feature or complex bugfix that should enter reviewer route
- Before merge / handoff when the current work needs repo-local acceptance
- After docs / skills / workflow rule changes that need consistency validation

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Refresh repo-local state first**

- Ensure the active task state file reflects the current Contract, latest `Evidence`, and current `Gaps`
- If the task is already on a reviewer route, keep using the current workflow rather than opening a separate review path

**2. Prepare the review brief**

Use the template at `code-reviewer.md` as a structured review brief for the current repo-local reviewer flow.

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{CHANGED_FILES}` - Files or modules touched in this round
- `{CHECKS_RUN}` - Commands, consistency checks, or manual paths actually run
- `{EVIDENCE_SUMMARY}` - Most relevant fresh evidence
- `{GAP_SUMMARY}` - Remaining risks or unverified areas
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Route into review**

- If current route is `single + reviewer` or `planner -> executor -> reviewer`, hand off to `ac-review`
- If review is being requested ad hoc, return to `ac-workflow` / current workflow path and request review there
- Do not dispatch external `Task tool` / `superpowers:code-reviewer` flow unless the active repo workflow explicitly supports it

**4. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Prepare repo-local review brief]
  WHAT_WAS_IMPLEMENTED: Login state handling and token refresh fallback
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/android-auth-flow.md
  CHANGED_FILES: feature/login/LoginViewModel.kt, data/auth/AuthRepository.kt, feature/login/LoginViewModelTest.kt
  CHECKS_RUN: ./gradlew test
  EVIDENCE_SUMMARY: Added tests for login success, refresh fallback, and expired token path
  GAP_SUMMARY: No low-memory process death validation yet
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added login state management and token refresh fallback for expired sessions

[ac-review returns]:
  Strengths: Clear state ownership, focused tests
  Issues:
    Important: Loading state not cleared on refresh failure
    Minor: Hard-coded timeout value in retry path
  Assessment: Ready to proceed

You: [Fix loading state reset]
[Continue to Task 3]
```

## Integration with Workflows

**Executing Plans:**
- Review after each declared batch or when the route enters reviewer stage
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Open a second review path that bypasses the active task state file
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
