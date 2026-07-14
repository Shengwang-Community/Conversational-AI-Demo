# Explicit Multi-Agent Contracts

Read this file only when the user or parent orchestrator explicitly authorizes delegation. Keep the parent Agent responsible for scope, acceptance criteria, and final synthesis.

## Handoff

Pass only:

- outcome and validation mode
- acceptance criteria
- owned or review-only files
- current diff and required upstream evidence
- exact validation method
- approved gap IDs
- maximum rounds (default 3)

Do not leak private source bodies or the intended review conclusion. Confirm the shared workspace contains the expected diff before starting verification.

## Developer Result

```json
{
  "status": "done|blocked",
  "changed_files": ["path"],
  "covered_criteria": ["criterion"],
  "suggested_validation": ["exact command or runtime path"],
  "summary": "delivered behavior",
  "gaps": ["unresolved blocker"],
  "accepted_gap_refs": ["product-gap-id"]
}
```

Developer rules:

- edit only owned scope and preserve unrelated changes
- add/update focused UT for logic
- do not invent external values or add placeholder production TODOs
- do not claim validation performed by another role

## Tester Result

```json
{
  "status": "passed|failed|blocked",
  "validation_mode": "logic|ui|mixed|docs",
  "covered_criteria": ["criterion"],
  "commands": [
    {
      "command": "exact command or runtime action",
      "result": "passed|failed|blocked",
      "artifacts": "rebuilt|reused|unknown",
      "summary": "observed result",
      "xcresult_path": "",
      "log_path": "",
      "screenshot_paths": []
    }
  ],
  "findings": [
    {
      "severity": "critical|high|medium|low",
      "file": "path",
      "line": 1,
      "description": "behavioral issue"
    }
  ],
  "gaps": [],
  "accepted_gap_refs": []
}
```

Tester rules:

- do not edit production files
- logic requires successful focused UT; build-only/static-only is not passed
- UI requires build/run, state inspection, key interaction, and screenshots when runnable
- if the required environment is unavailable after one focused retry, return blocked or cite an approved gap
- evaluate only the assigned outcome and report findings first

## Loop

- `passed`: parent verifies the evidence and closes the outcome.
- `failed`: return exact findings to the developer for the next bounded round.
- `blocked`: stop unless a safe in-scope environment fix or Product-approved gap resolves it.

Do not spawn another nested reviewer when the parent release runner already owns independent acceptance.
