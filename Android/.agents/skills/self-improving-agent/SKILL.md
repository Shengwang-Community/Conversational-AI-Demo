---
name: self-improving-agent
description: Summarize reusable workflow lessons after ac-review in this Android repo. Use when a workflow task finishes, when repeated mistakes or cross-document drift appear, or when the user explicitly asks for a retrospective or skill improvement.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Self-Improving Agent

Use this skill after a workflow task has completed review in this Android repository. It extracts reusable lessons, writes them into the skill's own `memory/`, and recommends whether a follow-up docs/skills workflow should adopt those lessons.

## Purpose

- Extract one structured episode from the current workflow's `PROJECT_STATE.md`, `Execution Contract`, `Evidence`, and `Gaps`
- Identify reusable workflow / docs / skills lessons and turn them into candidate patterns
- Maintain repo-local memory instead of taking over active workflow state
- Recommend an adoption path without directly modifying other rule assets

## When To Use

Use this skill when:

- `ac-review` has completed and the task is moving into summary
- Repeated mistakes, repeated unfreezes, cross-document drift, or recurring validation gaps appear
- Review has produced stable lessons worth turning into checklist or rule suggestions
- The user explicitly asks for a retrospective, self-improvement, or skill improvement

Do not use this skill when:

- `ac-review` has not happened yet
- The task is still in `ac-execute`
- The signal is one-off noise with no reusable lesson
- Someone is trying to use it as a background auto-corrector or auto-submission pipeline

## Inputs

Required inputs:

- `PROJECT_STATE.md`
- `AGENTS.md`
- `.agents/skills/ac-workflow/SKILL.md`
- `.agents/skills/ac-memory/SKILL.md`
- `.agents/skills/ac-plan/SKILL.md`
- `.agents/skills/ac-execute/SKILL.md`
- `.agents/skills/ac-review/SKILL.md`

Optional inputs:

- Files listed in the current `Execution Contract`
- Related `docs/*.md` files or target `SKILL.md` files when the task touches workflow / docs / skills assets

Primary evidence sources:

- `Key decision log`
- `Evidence`
- `Gaps`
- `Execution Contract`
- Actual changed files

## Process

1. Confirm review is complete.
- If `PROJECT_STATE.md` does not contain enough `Evidence` or `Gaps`, stop and return to the caller.

2. Extract one episode.
- Task type
- Route (`single` / `single + reviewer` / `planner -> executor -> reviewer`)
- Key files
- Key decisions
- Checks that actually ran
- Residual risks

3. Evaluate reusable knowledge.
- Generate a candidate pattern only when:
- The same class of issue repeats
- A rule omission caused rework or confusion
- A clear cross-document inconsistency was found
- A checklist improvement has sufficient evidence behind it

4. Persist only self-owned memory.
- Write to `memory/episodes/YYYY/YYYY-MM-DD-<slug>.json`
- Update `memory/pattern-candidates.json`
- Update `memory/working/latest-summary.md`
- Update `memory/semantic-patterns.json` only when a pattern is validated

5. Recommend adoption path.
- `none`
- `manual-review`
- `start-docs-workflow`

## Outputs

### Episode

Record one structured retrospective for a workflow task, including at least:

- Task summary
- Route
- Changed files
- Decisions and evidence
- Residual risks
- Related candidate patterns

### Candidate Patterns

Each candidate pattern must include at least:

- `id`
- `title`
- `summary`
- `confidence`
- `evidence_source`
- `suggested_targets`
- `adoption_status`

### Learning Summary

Output a short user-facing summary that includes:

- What was learned
- Why it is reusable
- Which files are the suggested targets
- Whether another docs/skills workflow is recommended

## Hard Rules

- Do not modify `AGENTS.md`, `PROJECT_STATE.md`, `docs/*.md`, or other skills directly.
- Do not auto-commit, auto-push, or auto-create PR.
- Do not invent evidence that is not present in `PROJECT_STATE.md` or changed files.
- Do not generalize from one-off noise.
- Treat `PROJECT_STATE.md` as the workflow source of truth for the current task.
- If adoption requires repo rule changes, ask for a separate docs/skills workflow task.

## Pattern Quality Bar

A candidate pattern must meet all of the following:

- Clear provenance
- A problem statement and solution that can be restated plainly
- Clear applicability boundaries
- A mapping to concrete target files
- No conflict with current `AGENTS.md` or `ac-*` workflow rules

## Suggested Targets In This Repo

Prioritize these assets in this repository:

- `AGENTS.md`
- `.agents/skills/ac-workflow/SKILL.md`
- `.agents/skills/ac-memory/SKILL.md`
- `.agents/skills/ac-plan/SKILL.md`
- `.agents/skills/ac-execute/SKILL.md`
- `.agents/skills/ac-review/SKILL.md`
- `docs/*.md` in the workflow / review / template area

## See Also

- `references/integration.md`
- `references/appendix.md`
- `memory/semantic-patterns.json`
- `memory/pattern-candidates.json`
