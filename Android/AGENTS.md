# Shengwang Android

See [shared guidance](../AI_WORKFLOW.md). Paths below are relative to Android unless stated otherwise.

- This repository uses only the `china` flavor. Build and test this brand's variant.
- `app` owns startup, Manifest and packaging; `common` provides shared UI, networking and configuration; `scenes:convoai` owns the main experience; `iot` uses `bleManager` for device connectivity.
- Java 17 is used by app/common/convoai; IoT and BLE use Java 11. The UI uses Activity, Fragment and ViewBinding.
- Toolkit is the Maven dependency `io.agora.agents:agora-agent-client-toolkit`, with its version in `gradle/libs.versions.toml`.
- For affected RTC/RTM, Toolkit, transcripts, permissions or BLE code, check callback threads, lifecycle, cancellation and cleanup. Preserve local configuration and existing user edits.

## Useful commands

From the repository root, `python3 scripts/validate.py android` runs this brand's debug unit tests and app lint. For a narrower change, choose relevant Gradle tasks instead.

From Android:

```bash
./gradlew :app:assembleChinaDebug
./gradlew :scenes:convoai:testDebugUnitTest --tests '<test-class>'
```

Choose checks for the change; docs usually need consistency checks rather than an app build. See [architecture](ARCHITECTURE.md), [setup](scenes/convoai/README.md) and the optional [review checklist](docs/PR_CHECKLIST.md).
