# iOS AI Collaboration Guide

This file records durable engineering facts, permission boundaries, and acceptance rules. Let the model derive task-specific steps from the requirement, the live code, and `convoai-ios-workflow`. Do not maintain a repository task-state machine.

## Project Facts

- Workspace and targets: use `Agent.xcworkspace`, the `Agent-cn` scheme, and CocoaPods. The app deployment target is iOS 15.0 and the project uses Swift 5.
- Ownership: `Agent` contains the application entry, `Scenes/ConvoAI/ConvoAI` owns the main product, `agent-client-toolkit-swift` owns the current Conversational AI API and transcript implementation, and `Common`, `IoT`, `BLEManager`, RTC, and RTM provide adjacent capabilities.
- UI: the app is UIKit and view-controller based. Preserve the current framework and patterns unless an explicit migration is required.
- Tests: `Agent-cnTests` is the application unit-test target. Prefer the focused test helpers under `scripts/`.
- Configuration: `Agent/KeyCenter.swift` feeds runtime values into `AppContext`. Never commit real App IDs, certificates, REST keys, LLM/TTS tokens, credentials, private requirement bodies, or user data.
- Architecture: use `ARCHITECTURE.md` for build topology, runtime flows, contract boundaries, and high-risk areas. Do not duplicate those details here.

## Working Agreement

- Recover context from the required outcome, current diff, relevant call sites, tests, and design evidence before choosing an implementation path.
- Use `.agents/skills/convoai-ios-workflow/SKILL.md` for iOS implementation and independent verification. Do not split a small task into artificial feature items.
- Stay single-Agent by default. Delegate only when the user or parent orchestrator explicitly authorizes it and the work separates into independent units.
- Preserve existing user changes. Do not reset, overwrite, or opportunistically refactor unrelated files.
- Do not commit, push, cherry-pick, or perform remote writes unless explicitly requested.
- When a server field, design asset, credential, device input, or production contract is missing, use an isolated mock or fixture only when authorized, or report a concrete blocker. Do not add production TODOs to simulate completion.
- When invoked by the repository release runner, report platform gaps but do not approve them. Reference only Product-approved gap IDs through `accepted_gap_refs`.

## Delivery Profiles

- `Direct`: a local, low-risk logic, copy, or documentation change with clear boundaries and acceptance criteria.
- `Standard`: the default for ordinary features and fixes. Add an independent diff, test, and requirement-coverage pass.
- `Full`: work involving modules or public APIs, UI/interaction, concurrency/lifecycle, RTC/RTM/transcripts, permissions/devices, Pods/project/schemes, migration, compatibility, security, or uncertain external contracts.

Use Full when the task needs an HLD, interaction design, or production-contract decision. Upgrade when new risk appears; do not route by file count.

## Engineering Constraints

- Preserve public API compatibility, delegate and callback semantics, and documented thread behavior unless the requirement explicitly changes them.
- Perform UI updates on the main thread. Check delegate lifetime, weak references, cancellation, repeated callbacks, and teardown.
- For Agent preset or REST changes, cover optional fields, defaults, payload omission, response decoding, error codes, SIP branches, and affected callers.
- For RTC, RTM, Presence, or transcript changes, cover ordering, reconnect, resubscription, missing fields, interruption, and lifecycle recovery.
- For camera, microphone, photos, Bluetooth, location, or background audio, cover authorization denial, retry, recovery, and device limitations.
- Explain workspace, CI, test, and consumer impact when modifying Pods, the project file, schemes, test plans, build settings, or resources.
- Update sample integration, focused tests, and adjacent README files when shared behavior changes.
- Keep Demo-owned v1 and v2 subtitle renderers separate from the published Toolkit-owned current transcript implementation.

## Validation

- Logic, API, storage, or parsing: add or update focused unit tests and execute them. A successful build does not replace logic tests.
- UI or mixed work: when a runnable environment exists, build and run the app, inspect required states and interactions, and retain screenshots and relevant logs. Prefer XcodeBuildMCP; otherwise use equivalent `xcodebuild` and Simulator tooling.
- If required UI runtime evidence is unavailable, return `blocked` or cite a Product-approved gap. Static inspection alone cannot pass UI acceptance.
- Build, Pods, project, scheme, or resource work: validate the affected workspace, scheme, configuration, simulator/device architecture, and consumers.
- Documentation or Skills: validate paths, terminology, commands, frontmatter, language, and dangling references. Do not claim unrelated Xcode build coverage.
- Every passing conclusion must list exact commands and results, whether artifacts were rebuilt or reused, focused test outcomes, and available `xcresult`, log, or screenshot paths.

Only fresh evidence can support `passed`.

## Review

- Lead with actionable findings ordered by severity and grounded in file and line references. If no issue is found, say so and report residual test risk.
- Critical or High findings must be `fixed`, `rejected with evidence`, covered by a Product-approved gap, or `blocked` before acceptance can pass.
- Platform reviewers may reference an approved `gap_id` but may not approve gaps themselves.

## Documentation

- Repository-maintained iOS AI and workflow documentation must be written in English: `AGENTS.md`, `ARCHITECTURE.md`, and `.agents/skills`.
- Product copy, localized resources, source comments, and explicitly localized README files follow their own product or localization rules.
- Keep profile, validation, delegation, and accepted-gap terminology aligned with the root release workflow.

## Reference Map

- `ARCHITECTURE.md`: build topology, runtime flows, contracts, and high-risk boundaries.
- `.agents/skills/convoai-ios-workflow/SKILL.md`: implementation and acceptance playbook.
- `.agents/skills/convoai-ios-workflow/references/ios_logic_ut.md`: focused unit-test helpers.
- `.agents/skills/convoai-ios-workflow/references/contracts.md`: explicit multi-Agent result contract.
- `Scenes/ConvoAI/README.md`: product setup and module navigation.
