# Repository guide

For a product requirement, start with the [maintainer workflow](AI_ENGINEERING.md) to identify affected platforms and brand differences. Read [AI_WORKFLOW.md](AI_WORKFLOW.md) and the relevant [Android](Android/AGENTS.md), [iOS](iOS/AGENTS.md) or [Web](Web/Scenes/VoiceAgent/AGENTS.md) guide for implementation.

- Use judgment to complete the user's goal with appropriate tools, checks and review.
- Preserve existing user changes, local App IDs and credentials. Keep secrets out of docs and commits.
- `cicd/` belongs to Jenkins; change it only when the user requests Jenkins work.
- Follow the user's language in conversation. Write AI guidance and related engineering docs in English.
- Commit, push, publish or send external messages only within the user's authorization.
