# Knowledge Index

Product/Intake reads this index for every profile. Full runs delegate deeper repository grounding to Knowledge, Architect, Test Design, and platform roles. Keep knowledge at its existing owner instead of copying it into prompts.

## Android

- `Android/AGENTS.md`: durable project facts, engineering constraints, profile selection, and validation requirements.
- `Android/ARCHITECTURE.md`: modules, primary flows, and high-risk paths.
- `Android/.agents/skills/ac-workflow/SKILL.md`: risk-based Android delivery playbook.

## iOS

- `iOS/AGENTS.md`: durable project facts, engineering constraints, and runtime acceptance requirements.
- `iOS/.agents/skills/convoai-ios-workflow/SKILL.md`: risk-based iOS delivery playbook.
- `iOS/.agents/skills/convoai-ios-workflow/references/ios_logic_ut.md`: focused UT helpers and retry rules.
- `iOS/.agents/skills/convoai-ios-workflow/references/contracts.md`: explicit multi-Agent handoff contracts.

## Web

- `Web/Scenes/VoiceAgent/README.md`: application setup and development entrypoint.
- `Web/Scenes/VoiceAgent/package.json`: validation commands and dependency scripts.

## Knowledge Maintenance

Update platform guidance at its owner. Add a durable rule only when it changes future behavior and has evidence; keep one-off requirement detail inside the ignored run workspace. Requirement briefs, source summaries, HLD, UX artifacts, test matrices, verification, and runtime evidence must not be committed here.
