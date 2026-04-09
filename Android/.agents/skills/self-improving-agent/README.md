# Self-Improving Agent

Use this skill to run a structured retrospective after `ac-review` has completed in the current repository. It extracts reusable lessons from `PROJECT_STATE.md`, the `Execution Contract`, `Evidence`, and `Gaps`, stores them in the skill's own `memory/`, and suggests whether another docs/skills workflow should adopt them.

## When To Use

- `ac-review` has completed
- Repeated mistakes, rule drift, cross-document inconsistencies, or recurring validation gaps appear
- The user explicitly asks for a retrospective, self-improvement, or a lesson summary

## What It Does Not Do

- It does not automatically modify `AGENTS.md`, `docs/*.md`, or any other `SKILL.md`
- It does not automatically commit, push, or create PRs
- It does not replace `PROJECT_STATE.md` as the workflow state source of truth
- It does not run in the background during `ac-execute`

## Typical Repository Flow

```text
ac-workflow -> ac-memory -> ac-plan -> ac-execute -> ac-review -> self-improving-agent (optional) -> summary
```

## Memory Layout

```text
.agents/skills/self-improving-agent/memory/
|-- semantic-patterns.json
|-- pattern-candidates.json
|-- episodes/
`-- working/
    `-- latest-summary.md
```

## Outputs

- episode: one structured retrospective record for a workflow task
- candidate patterns: lessons that may be adopted later
- learning summary: a short user-facing summary

These outputs are treated as local runtime artifacts by default:

- `memory/pattern-candidates.json`
- `memory/working/latest-summary.md`
- `memory/episodes/**/*.json`

They usually stay out of commits. Prefer committing structural assets and stable rules rather than the latest run output.

## Adoption Path

If a candidate pattern is worth turning into a repository rule:

1. Mark it as `manual-review` or `start-docs-workflow` in the summary
2. Start a new docs/skills workflow
3. Then update `AGENTS.md`, other `SKILL.md` files, or `docs/*.md`

## Reference Files

- `references/integration.md`
- `references/appendix.md`
- `templates/pattern-template.md`
- `templates/correction-template.md`
- `templates/validation-template.md`
