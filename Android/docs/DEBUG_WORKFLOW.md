# Android Debugging and Integration

The goal of debugging is to isolate the responsible boundary with the least sufficient evidence and leave a conclusion that another engineer can reproduce.

## Before Investigation

- Record the observed behavior, expected behavior, first known occurrence, and impact.
- Record the device or emulator, Android version, variant, network, permissions, account state, and backend environment.
- Declare local-cache or debug-data behavior, active mocks, backend assumptions, and non-goals.
- Build the smallest reproduction before considering broad refactoring.

## Investigation Order

1. Reproduce the issue and retain fresh logs, screenshots, recordings, or a failing test.
2. Narrow the boundary along UI -> ViewModel/state -> API/SDK -> server/device.
3. Design one check that can confirm or reject each leading hypothesis.
4. Mark conclusions as confirmed, rejected, or unverified. Put unverified items in Gaps.
5. Fix the root cause and retest the original path, the failure path, and adjacent successful paths.

## Evidence Priority

1. A repeatable automated test.
2. Actual command output and Logcat, network, or SDK logs.
3. Runtime interaction and screenshots from an emulator or device.
4. Static call-chain and diff inspection.

Historical logs provide context only. When the problem cannot be reproduced, record why and identify the missing environment or input. Do not present static inference as a runtime result.

## Development-Integration Boundary

For development-integration review, state:

- which values come from a mock, local cache, fixture, or temporary configuration;
- which server behavior is assumed;
- what is explicitly out of scope;
- which concerns remain assumptions or open questions.

A declared development assumption is not automatically a release defect, but report it when current code evidence contradicts the assumption.

## When to Expand Scope

Stop the current repair and reassess the profile and scope when:

- responsibility crosses into another module or shared contract;
- the solution requires a new backend, permission, device, migration, or compatibility policy;
- the planned validation no longer covers the discovered risk;
- rollback behavior or user-data impact changes.

## Completion Language

Use "fixed" only when the symptom is defined, the root cause is supported by evidence, the change matches that cause, and fresh validation passes. Otherwise use a precise state:

- implementation updated; validation pending;
- implementation passed local checks; acceptance is incomplete;
- root cause identified; repair pending;
- blocked: missing <specific environment or external input>.

## Result Template

```markdown
- Symptom:
- Reproduction conditions:
- Responsible boundary:
- Root cause or leading hypothesis:
- Change:
- Fresh evidence:
- Gaps:
- Conclusion:
```
