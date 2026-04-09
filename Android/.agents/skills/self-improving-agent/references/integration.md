# Integration

## Workflow Placement

`self-improving-agent` sits after `ac-review` in this repository and is used as an optional retrospective step:

```text
ac-workflow -> ac-memory -> ac-plan -> ac-execute -> ac-review -> self-improving-agent (optional) -> summary
```

It is not a background auto-trigger and it does not replace the `ac-*` state machine.

## Read Scope

Required reads:

- `PROJECT_STATE.md`
- `AGENTS.md`
- `.agents/skills/ac-workflow/SKILL.md`
- `.agents/skills/ac-memory/SKILL.md`
- `.agents/skills/ac-plan/SKILL.md`
- `.agents/skills/ac-execute/SKILL.md`
- `.agents/skills/ac-review/SKILL.md`

Optional reads:

- Files listed in the current `Execution Contract`
- Related `docs/*.md` or other `SKILL.md` files touched by the task

## Write Scope

Only write to the following files:

- `.agents/skills/self-improving-agent/memory/semantic-patterns.json`
- `.agents/skills/self-improving-agent/memory/pattern-candidates.json`
- `.agents/skills/self-improving-agent/memory/episodes/**`
- `.agents/skills/self-improving-agent/memory/working/latest-summary.md`

The following files are treated as local runtime outputs by default and usually stay out of commits:

- `.agents/skills/self-improving-agent/memory/pattern-candidates.json`
- `.agents/skills/self-improving-agent/memory/working/latest-summary.md`
- `.agents/skills/self-improving-agent/memory/episodes/**/*.json`

## Forbidden

- Do not modify `AGENTS.md` directly
- Do not modify `PROJECT_STATE.md` directly
- Do not modify `docs/*.md` directly
- Do not modify other `SKILL.md` files directly
- Do not auto-commit, auto-push, or auto-create PRs

## Adoption Path

When a candidate pattern is worth adopting:

1. Call out the suggested target files in the current summary
2. Mark the outcome as `manual-review` or `start-docs-workflow`
3. Start a new docs/skills workflow
4. Use the new `Execution Contract` to update repository rule assets formally
