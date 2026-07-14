# Android Review Template

Review against the requirement, the live code, and fresh evidence, not the implementer's summary.

## Output Order

1. Findings, ordered Critical, High, Medium, then Low. Include file, line, behavioral impact, and a concrete repair.
2. Open questions or assumptions that can change the conclusion.
3. Acceptance status: `passed`, `failed`, or `blocked`, with the supporting criteria.
4. Validation: exact commands, results, runtime evidence, and uncovered scope.

When there are no findings, state that no actionable issue was found and report residual test risk.

## General Review

- Map every acceptance criterion to implementation and evidence.
- Confirm module ownership and reject unrelated refactoring.
- Check invalid input, errors, timeouts, cancellation, concurrency, lifecycle, and recovery.
- Check compatibility of public APIs, serialization, caches, storage, configuration, and consumers.
- Check logs, fixtures, screenshots, and committed content for credentials or private source material.
- Confirm that tests target the changed behavior and were actually executed.

## Android-Specific Review

- Activity, Fragment, ViewModel, observer, and lifecycle safety.
- Coroutine scope, dispatcher, Flow or StateFlow use, and cancellation propagation.
- Agent preset and REST request/response contracts, including optional fields, defaults, failure codes, and SIP branches.
- Manifest, flavor, `BuildConfig`, resources, dependency, and Gradle impact on affected variants.
- Camera, microphone, Bluetooth, location, and Wi-Fi denial, retry, recovery, and Android-version behavior.
- RTC, RTM, SIP, transcripts, IoT, and BLE ordering, disconnect, reconnect, and device limitations.
- Requirement-relevant loading, empty, error, success, dark theme, orientation, and accessibility behavior.

## Acceptance by Profile

- `Direct`: the same Agent may self-review, but focused test and compile evidence are still required.
- `Standard`: independently inspect the diff, acceptance criteria, and platform evidence.
- `Full`: independently inspect architecture, UX, test design, and runtime evidence. Acceptance cannot pass with an unresolved Critical or High finding.

## Integration and Fix Reviews

- Development-integration review: evaluate declared mocks, backend assumptions, local cache behavior, and non-goals first. Keep missing evidence as an assumption or open question instead of inventing a release regression.
- Fix review: verify the original symptom, root cause, failing regression test or reproduction, passing post-fix evidence, and adjacent paths.

## Finding Closure

Close each finding with exactly one outcome:

- `fixed`;
- `rejected with evidence`;
- `accepted gap` with a Product-approved `gap_id`;
- `blocked`.

Stop acceptance and reassess the profile and scope when a finding requires a materially different design or boundary.

## Compact Output

```markdown
## Findings
1. [High] path/to/File.kt:42 - Behavioral impact.
   Repair: ...

## Open Questions
- ...

## Acceptance
- Status: passed | failed | blocked
- Criteria covered: ...
- Validation: <exact command> -> <result>
- Gaps: ...
```
