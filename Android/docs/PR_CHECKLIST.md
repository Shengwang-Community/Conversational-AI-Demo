# Android Change Review Checklist

Apply only the checks relevant to the change. Explicitly report checks that were not run; do not treat them as passed.

## Scope and Requirement

- [ ] The user-visible outcome and acceptance criteria are clear and match the diff.
- [ ] The change contains no unrelated refactor, generated output, private requirement body, or credential.
- [ ] Files are owned by the correct module, and shared-module impact is described.
- [ ] External dependencies such as backend contracts, Figma, assets, or devices have evidence or a concrete gap.

## Kotlin and Architecture

- [ ] Nullability, invalid input, errors, timeouts, cancellation, and boundary values are handled.
- [ ] Coroutines, threads, Flow, and lifecycle behavior are sound.
- [ ] Public APIs, payload serialization, caches, storage, and consumers remain compatible.
- [ ] `app` has not absorbed product logic, and `common` changes include consumer checks.
- [ ] Agent preset and REST payload changes cover defaults, field omission, response parsing, and affected call sites.

## UI and Device Behavior

- [ ] Required loading, empty, error, and success states are implemented.
- [ ] Navigation, back stack, configuration recreation, process or foreground recovery, and lifecycle behavior have no known regression.
- [ ] Permission denial, retry, and recovery paths are covered.
- [ ] BLE, IoT, RTC, RTM, SIP, and transcript environment limits are tested or recorded as gaps.
- [ ] UI work includes runtime inspection and necessary screenshots; static inspection alone is not reported as passed.

## Build and Tests

- [ ] New logic has focused coverage or a documented reason it cannot be automated.
- [ ] Relevant test classes or module tests actually passed.
- [ ] Affected modules compile.
- [ ] Validation expands to consumers, variants, assemble, lint, integration, or devices only when the boundary requires it.
- [ ] The final report includes exact commands, results, and unverified scope.

## Documentation and Skills

- [ ] `AGENTS.md`, `.agents/skills`, and `docs` use consistent Direct, Standard, and Full semantics.
- [ ] Android AI and workflow documentation is written in English.
- [ ] Skill frontmatter describes both capability and trigger conditions without duplicating a task-state machine.
- [ ] No dangling reference points to a removed Skill, template, or state mechanism.
- [ ] Paths and example commands match the live repository.

## Review Conclusion

- [ ] Findings are ordered by severity and include a file and line reference.
- [ ] Every Critical or High finding is fixed, rejected with evidence, covered by a Product-approved gap, or blocked.
- [ ] `passed` is supported by fresh evidence from this change.
- [ ] Commit and push occur only when explicitly requested.
