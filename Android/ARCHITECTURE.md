# Shengwang Android architecture

This demo combines conversational AI, Agora RTC/RTM, transcripts, vendor configuration and IoT/BLE connectivity. See [project guidance](AGENTS.md) and [setup](scenes/convoai/README.md) for commands and configuration.

## Modules

| Module | Responsibility |
|---|---|
| `app` | Startup, `china` flavor, Manifest, signing, APK naming and app BuildConfig |
| `common` | Shared UI, networking, storage, Agora configuration and utilities |
| `scenes:convoai` | Login, agent list, Living/SIP sessions, transcripts, avatars and settings |
| `scenes:convoai:iot` | Device setup, permissions, scanning, Wi-Fi provisioning and connections |
| `scenes:convoai:bleManager` | BLE support used by IoT |
| External Toolkit | RTC/RTM messaging, transcript and metrics APIs |

`app` uses `common` and `scenes:convoai`; the scene uses `common`, Toolkit and IoT. IoT uses `common` and BLEManager. Toolkit is downloaded as `io.agora.agents:agora-agent-client-toolkit`; the version is maintained in `gradle/libs.versions.toml`.

## Main paths

- Startup: `WelcomeActivity` checks login state through `SSOUserManager`, then opens `CovLoginActivity` or `CovMainActivity`. The main screen leads to agent selection, Living and SIP sessions.
- Conversation: Living/SIP ViewModels initialize `ConversationalAIAPIImpl` with RTC and RTM clients. `IConversationalAIAPIEventHandler` returns messages, transcripts, interruption events and metrics to the UI. The public Toolkit package is `io.agora.conversational.api`; the demo retains a legacy transcript renderer under `ui/living/legacy`.
- Devices: device list -> setup and permission checks -> scan -> Wi-Fi selection -> connection. Bluetooth, location, Wi-Fi and device state affect this path; simulator coverage is limited.

Useful source roots:

- `common/src/main/java/io/agora/scene/common/{ui,net}`
- `scenes/convoai/src/main/java/io/agora/scene/convoai/{ui,api,rtc,rtm}`
- `scenes/convoai/iot/src/main/java/io/agora/scene/convoai/iot/ui`

## Configuration and compatibility

Android `gradle.properties` supplies toolbox, Agora and vendor settings. `app/build.gradle` emits app configuration; `common/build.gradle` emits shared `BuildConfig` values for networking and LLM/TTS/Avatar requests. Trace runtime overrides in the consuming code when changing configuration. Keep local credentials private.

App/common/convoai use Java 17; IoT/BLEManager use Java 11. Build files, the version catalog and Manifests affect dependency compatibility, flavor selection, configuration and permissions. Runtime paths depend on the toolbox/agent service, Agora SDKs and configured providers.

For changes in shared code, consider all consuming scenes. For session or transcript changes, check callback delivery, ordering, threads and release. For device changes, include relevant permission denial, Bluetooth/location availability and reconnect behavior. Use [the review checklist](docs/PR_CHECKLIST.md) when helpful.

Toolkit details: [component documentation](https://github.com/AgoraIO-Conversational-AI/agent-client-toolkit-kotlin/blob/main/conversational-ai/README.md).
