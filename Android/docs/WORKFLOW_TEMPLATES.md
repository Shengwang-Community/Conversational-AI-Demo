# Task prompts

Optional prompts for planning work; use only what helps. [Shared guidance](../../AI_WORKFLOW.md) applies without requiring these templates.

| Task | Useful questions | Typical checks |
|---|---|---|
| Feature | What should users be able to do? Which states and errors matter? | Relevant tests and affected user paths |
| Fix | What triggers the defect? What evidence identifies the cause? | Reproduction or regression test and adjacent paths |
| Refactor | What is being simplified? Which behavior should be preserved? | Tests covering those behaviors |
| Build or dependency | Which modules and variants are affected? | Relevant build, compatibility and configuration checks |
| Docs or skills | What context is useful? Is any rule redundant or restrictive? | Paths, commands, English wording and consistency |

For a long task, a short note with **goal, decisions, checks and next step** can support recovery. Implementation and completion do not depend on creating a note or filling every field.
