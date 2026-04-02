# iOS Logic UT Guide

Use this guide only for `validation_mode = logic`.

## Purpose

This file explains how to use the helper scripts for iOS logic UT in this repo.

Keep the shell logic in `scripts/`.
Keep this file focused on:
- when to run each script
- which arguments to pass
- what the script output means
- when to do one manual fallback retry

## Script 1: Preflight

Use:
- `scripts/preflight_ios_logic_ut.sh`

Purpose:
- verify workspace discovery
- verify project targets
- verify the shared scheme has `Testables` and `MacroExpansion`
- list available simulators so the controller/tester can choose a UUID

Arguments:
1. workspace path
2. project path
3. scheme name
4. shared scheme file path

Default invocation:

```bash
scripts/preflight_ios_logic_ut.sh Agent.xcworkspace Agent.xcodeproj Agent-cn Agent.xcodeproj/xcshareddata/xcschemes/Agent-cn.xcscheme
```

Expected result:
- success means the basic test entrypoints are wired
- a non-zero exit usually means scheme wiring is broken and should be routed back to the developer

## Script 2: Focused UT Run

Use:
- `scripts/run_ios_logic_ut.sh`

Purpose:
- boot the chosen simulator if needed
- run one focused `xcodebuild test` command against the workspace

Arguments:
1. workspace path
2. scheme name
3. simulator UUID
4. `-only-testing:` identifier
5. derived data path

Default invocation:

```bash
scripts/run_ios_logic_ut.sh Agent.xcworkspace Agent-cn SIMULATOR_UUID Agent-cnTests/LatencyMetricsLogicTests /tmp/AgentDerivedData
```

Expected result:
- success means the focused UT command completed
- failure means either the test/build failed or the environment still needs one targeted retry

## Default Usage Pattern

1. Run preflight first.
2. Pick a concrete simulator UUID from the preflight output.
3. Run the focused UT script with the narrowest `-only-testing:` identifier that still covers the acceptance criteria.

## One-Shot Retry Rules

If the first focused UT attempt fails for an obvious local iOS reason, allow one targeted retry:

- If dependency resolution looks wrong because `-project` was used, switch to `-workspace`.
- If the simulator is not booted, boot it and retry.
- If arm64 simulator linkage fails on a legacy dependency, retry once with manual arch overrides:

```bash
xcodebuild test \
  -workspace Agent.xcworkspace \
  -scheme Agent-cn \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID,arch=x86_64' \
  -only-testing:Agent-cnTests/LatencyMetricsLogicTests \
  -derivedDataPath /tmp/AgentDerivedData-x86 \
  ONLY_ACTIVE_ARCH=YES ARCHS=x86_64 EXCLUDED_ARCHS=arm64
```

Route back to the developer instead of retrying when:
- the shared scheme is missing `Testables` or `MacroExpansion`
- the focused test file itself does not compile
- the failure is clearly an actionable code/test defect rather than an environment issue
