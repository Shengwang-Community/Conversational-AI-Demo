# AI engineering for maintainers

These public repositories provide reference Demo code. Maintenance is handled internally; external pull requests are not accepted at this time. AI tools may help with implementation, but the developer remains responsible for reviewing the result and recording real verification.

## One requirement across platforms and brands

Define the expected behavior once for a requirement. Record which of this repository's Web, Android and iOS targets are affected. Keep decisions for other repositories in the requirement or issue record. One developer owns implementation across the affected targets; separate platform roles or handoff documents are not required.

- Web is developed and tested in the internal `convoai-demo/web-next` project first. Sync the tested change into `Web/Scenes/VoiceAgent` in each applicable public repository, then validate each synced target. Keep the internal source commit or revision in the PR record so the copy can be traced.
- Android and iOS implement the behavior applicable to this repository's brand and configuration. Record intentional exceptions in the requirement or issue record.
- A requirement may affect only one repository or platform. Record that scope instead of creating empty tasks or claiming unrun checks for other targets.

### Mobile requirement record

For Android or iOS work, record the requirement ID and observable acceptance behavior, including relevant failure and cleanup paths. The requirement or issue record owns the cross-repository scope. In this repository's PR, account for Android and iOS independently: mark each as changed, unaffected or an intentional exception, with a reason. Matching files are not evidence of matching behavior.

Link any related repository PR, or explain why this requirement affects only this repository. For every changed target, record the checks actually run and any device or service path still unverified. Keep development, QA and release status separate. Use the [mobile PR template](.github/PULL_REQUEST_TEMPLATE/mobile.md) for Android or iOS work (`gh pr create --template .github/PULL_REQUEST_TEMPLATE/mobile.md`); Web keeps its existing workflow.

## Development, QA and main branch

Work on a branch and use an internal GitHub pull request for each affected public repository. The PR is the review and acceptance record for that repository. Include the requirement scope and brand exceptions, relevant Web source revision, checks actually run on each changed target, QA findings and resolution, release version or deployment confirmation, and remaining risks. Review the final diff for local configuration, credentials and generated output.

After development, QA validation and release are complete, merge the reviewed PR into that repository's `main` branch. If a release or QA check is still pending, keep its result visible in the PR and defer the merge. A Web sync or a successful build alone does not establish that the public target passed QA. Use the [default PR template](.github/pull_request_template.md) for non-mobile work.

## Guidance and checks

| Scope | Project context | Relevant checks |
| --- | --- | --- |
| Shared | [AGENTS.md](AGENTS.md), [AI_WORKFLOW.md](AI_WORKFLOW.md) | `python3 scripts/check_workflow.py` for guidance or test wiring. |
| Android | [Android/AGENTS.md](Android/AGENTS.md), [setup](Android/scenes/convoai/README.md) | Relevant Gradle task or `python3 scripts/validate.py android` for unit tests and lint. |
| iOS | [iOS/AGENTS.md](iOS/AGENTS.md), [validation guide](iOS/docs/VALIDATION.md) | `python3 scripts/validate.py ios --list`, then a relevant suite. |
| Web | [Web/Scenes/VoiceAgent/AGENTS.md](Web/Scenes/VoiceAgent/AGENTS.md), [setup](Web/Scenes/VoiceAgent/README.md) | Relevant `bun run test`, `bun run typecheck`, `bun run lint` and `bun run build` checks, plus affected browser flows. |

`AGENTS.md` files are tool-neutral instructions; `CLAUDE.md` files point to them. Platform guides are implementation references, not separate approval tracks. Use focused checks for the changed behavior and state what needs a device, account or service to verify. Run `python3 -m unittest discover -s scripts/tests -v` when changing validation scripts. Do not copy internal credentials, deployment details or local test artifacts into the public repositories.
