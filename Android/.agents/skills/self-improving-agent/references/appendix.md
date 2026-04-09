# Appendix

## Validation Report Template

```markdown
## Validation Report

**Date**: [YYYY-MM-DD]
**Scope**: [skill(s) or docs validated]

### Checks
- [ ] Candidate patterns map to real evidence
- [ ] Suggested targets match current repo paths
- [ ] New guidance does not conflict with `AGENTS.md`
- [ ] Remaining risks are captured in `Gaps`

### Findings
- [Finding 1]
- [Finding 2]

### Actions
- [Action 1]
- [Action 2]
```

## Repo-Local Memory Structure

```text
.agents/skills/self-improving-agent/memory/
|-- semantic-patterns.json
|-- pattern-candidates.json
|-- episodes/
|   `-- YYYY/
|       `-- YYYY-MM-DD-<slug>.json
`-- working/
    `-- latest-summary.md
```

## Learning Summary Template

```markdown
## Learning Summary

### Episode
- Task:
- Route:
- Key files:

### Candidate Patterns
1. [title] - [summary] - confidence: [0.00]

### Suggested Targets
- [file/path]

### Adoption
- none | manual-review | start-docs-workflow
```

## Candidate Pattern Notes

- `confidence` reflects current evidence strength only; it does not imply automatic adoption
- `suggested_targets` must point to real repository paths
- `adoption_status` should use `candidate`, `validated`, or `rejected`

## References

- `references/integration.md`
- `templates/pattern-template.md`
- `templates/correction-template.md`
- `templates/validation-template.md`
