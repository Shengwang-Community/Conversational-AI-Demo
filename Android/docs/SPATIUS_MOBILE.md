# Spatius mobile rendering (Android and iOS)

This guide applies to non-open-source mode, where business presets can enable digital humans. Open-source mode is voice-only and does not offer an avatar selection.

The mobile clients attach AvatarKitRTC to the existing Agora engine before joining the channel. Agora continues to own microphone capture, audio playback and channel membership. Keep video subscriptions enabled: the avatar publisher's encoded video carries the animation data. Do not bind that video to the ordinary remote video view for Spatius.

## Backend metadata

Standard presets select a record from `avatar_ids_by_lang`. A Spatius record uses `vendor: "spatius"`, `avatar_id` and the existing display/image fields. Supply the public App ID in `data[i].extensions.spatius_app_id` in the `/convoai/v5/presets/list` response: `extensions` is a preset-level object alongside `name` and `avatar_ids_by_lang`. The supplied response has no preset or avatar `region`; the clients use `auto`.

The supplied response has no custom preset or preset-level `spatius_avatar_id`. A custom Spatius selection cannot resolve a client avatar ID and follows the missing-metadata path; it never reuses a stale standard avatar. Confirm the custom search response before enabling local rendering for custom presets.

The client does not add these rendering fields to business REST requests. Standard requests retain the generic avatar vendor, avatar ID and Agora UID; custom requests retain the existing server-controlled selection. Spatius API keys remain on the server.

App IDs come only from backend metadata in both Debug and Release. Neither client reads a local environment variable or uses a local default. Missing or blank backend App IDs follow the rendering-warning behavior described below.

Both clients use `bg_img_url` as a loading poster, center-cropped directly to fill the display window. `web_bg_img_url` is Web-only and is not read by either mobile client. They keep the same poster from idle through connecting, hide it on the current session's first rendered frame, and restore it on cleanup. A poster containing a person must not remain behind the transparent renderer: it can show through as a second static person. Until a separate, matching background without the avatar is supplied, the renderer uses the application's opaque background color.

## Adaptive windows

The display window follows its parent bounds, including compact/expanded foldable screens, split windows and the floating preview. The internal 16:9 stage preserves AvatarKit's coordinate system; it does not impose a 16:9 UI. Both clients cover the complete window, using `stageHeight = max(windowHeight, windowWidth * 9 / 16)`, and center the 16:9 stage. Tall windows crop horizontal overflow; windows wider than 16:9 crop vertical overflow. Scaling is uniform, and no height cap leaves an uncovered strip at the top or bottom. The opaque background prevents an underlying preview from leaking through the transparent model. Dimensions are resolved before rendering in Android measurement and iOS layout; window changes do not create a new avatar session. Extreme aspect ratios necessarily crop more of the model and need device-level framing checks.

The loading poster remains outside this stage and receives only one crop. A Spatius Studio background, when integrated, must share the renderer's stage and transform; promotional posters do not establish that alignment. The static poster's composition may still differ from the model's first frame.

On iOS, switching the poster and stage from SnapKit constraints to manual frames must also restore `translatesAutoresizingMaskIntoConstraints`. Otherwise AvatarKit's internally constrained views can resolve to zero size even while the outer stage has a nonzero frame, preventing the Metal layer from producing a drawable. Restore ordinary constraints when switching back to another avatar vendor.

Android observes Jetpack WindowManager folding features in the current window. A separating fold or occluding hinge places the complete call UI in the largest uninterrupted pane; ties use the top/left pane. Flat, non-separating folds use the full window. Window coordinates are converted to root-view coordinates, and every pane is recomputed when the window changes. The living Activity handles size/orientation/layout configuration changes without recreation; the phone's existing portrait-orientation policy is retained. Other causes of Activity/process recreation are outside this size-change handling. Floating-window drag offsets are clamped when its parent shrinks. iOS uses view bounds and safe-area constraints, without device-name or global-screen-size checks.

The iOS app target still declares iPhone-only, full-screen support. Testing geometry at tablet/split sizes does not enable iPad distribution or multitasking; those require a separate whole-app adaptation. No unsupported device-specific fold API is assumed on iOS.

## Dependencies

- Android: AvatarKit 1.3.4, AvatarKitRTC 1.0.1 and Agora RTC 4.6.4, plus AndroidX WindowManager 1.4.0 for folding features. AvatarKitRTC implements the four-argument encoded-video callback (channel, UID, buffer, frame info); Agora 4.5.1 exposes only the two-argument callback and is binary-incompatible. That mismatch can leave audio and idle animation working while speech animation receives no frames. `SpatiusRtcCompatibilityTest` checks the actual resolved callback implementation. AvatarKit requires Kotlin 2.2.20 and compile SDK 36; the project uses AGP 8.10.1 and Gradle 8.11.1. Target/min SDK are unchanged. The SDK provides only arm64 native rendering; on other ABIs, selecting Spatius ends the call with an error.
- iOS: AvatarKitRTC 1.0.1, SpatiusAvatarKit 1.3.4 and ShengwangRtcEngine_iOS 4.6.4. Upstream AvatarKitRTC and AvatarKitAgoraBridge 1.0.1 pin RTC 4.5.2. The local integration in `iOS/ThirdParty/Spatius` selects the domestic RTC Pod, overrides those constraints and adds the channel ID to the native encoded-frame callback for RTC 4.6.4; the Swift adapter source remains pinned to upstream commit `f4548dffdec3f9a248a3193dfbf87320e33e4d0a`. The Podfile, ConvoAI podspec, app and test targets use iOS 16 as their minimum. The post-install hook raises older Pod deployment targets to that minimum because Xcode 27 rejects targets below iOS 15, while preserving any higher requirements. The simulator SDK supports Apple Silicon only.

Both clients use RTM 2.3.0. Android uses `cn.shengwang.rtm:android-java:2.3.0`; iOS uses `ShengWang-Rtm/RtmKit` 2.3.0. The older Maven coordinate `io.agora:agora-rtm` and Pod name `AgoraRtm` do not publish this version; `ShengwangRtm` only publishes through 2.2.7. Java package and Swift module names remain unchanged. Android RTM 2.3 changes `release()` from a static method to an instance method; cleanup releases the captured client even when logout fails.

Android uses `cn.shengwang.rtc:full-sdk:4.6.4` and `cn.shengwang.rtm:android-java:2.3.0`. Both depend on `cn.shengwang.infra:aosl:1.3.5`, so Gradle resolves one shared library. No direct AOSL dependency, AOSL exclusion or `pickFirst` packaging rule is needed. Keep RTC and RTM on the same publisher coordinates, and verify the dependency graph and packaged libraries after SDK upgrades.

iOS uses `ShengwangRtcEngine_iOS` 4.6.4, selects only RTM's `RtmKit` subspec and shares the AOSL supplied by `ShengwangInfra_iOS` 1.3.5. The official Toolkit 2.10.1 spec still names the Agora RTC and RTM Pods, so `iOS/ThirdParty/AgentClientToolkit` changes only those dependencies to `ShengwangRtcEngine_iOS` and `ShengWang-Rtm/RtmKit` while fetching the unchanged official Toolkit binary. Swift module names remain `AgoraRtcKit` and `AgoraRtmKit`. Keep only one of each SDK framework and one AOSL framework in the app.

## Audio extensions and demo assets

RTC 4.6.0 and later no longer require the separately distributed `common_resource.zip` audio models. Android loads the AIAEC and AINS extension providers when creating its engine; the full RTC dependency supplies their native libraries. iOS links and embeds the AIAEC and AINS frameworks through the full RTC Pod. Keep the existing Toolkit audio-scenario settings and user AINS override.

Neither app extracts the legacy audio models on startup. Android excludes stale `common_resource` assets from packaging, and iOS removes the archive from the app resources. Both platforms use the domestic [v2.0.0 demo resource archive](https://accktvpic.oss-cn-beijing.aliyuncs.com/ConvoAI/Resource/Convo_AI_Demo_v2.0.0_Resource.zip) for the two ball-animation videos. This archive contains no RTC models. Resource hooks extract only `ball_video_start.mp4` and `ball_video_rotating.mp4`, ignoring macOS archive metadata, and skip downloading when both videos already exist. Keep one parent directory around the MP4 files in the archive to match both extraction rules. Android versions the ZIP cache filename to avoid reusing the legacy download. No RTC model archive is packaged or loaded.

## SDK configuration changes

AvatarKit 1.3.4 on both native platforms ignores repeated initialization and exposes no public reset API. A process-wide guard records the App ID and requested region only after initialization returns successfully. Reconnecting or selecting another avatar with the same configuration reuses the SDK. Changing the App ID or region skips model loading, stops the Agent and shows a restart-required message. Returning to the original configuration works without restarting. To use a changed configuration, fully quit and relaunch the app, then select that preset. Closing the renderer does not reset this guard. The requested `auto` region is compared as `auto`, independently of the SDK's resolved region.

Hot switching these fields requires a supported reset/reconfiguration API from Spatius; clearing models alone is insufficient. No private SDK state is modified.

## Failure and cleanup behavior

On Android and iOS, missing metadata, unsupported devices, model loading failures, renderer errors and first-frame timeouts all stop the Agent and leave RTC. The user sees a failure message after the call ends. A 30-second first-frame watchdog starts after model loading, not during download. Model loading has a separate 90-second timeout. Android's independent watchdog cancels the SDK download, and its connection coroutine stops waiting even if the synchronous SDK call remains blocked. iOS cancels the asynchronous SDK load when its deadline expires.

Hangup cancels preparation and model loading, invalidates callbacks, removes the encoded-frame observer before RTC leave/destroy, and releases the local renderer. Renderer cleanup does not own or destroy the host engine. Existing RTC/agent startup failures retain their normal failure handling.

## Validation

```sh
cd Android
./gradlew :scenes:convoai:testDebugUnitTest :app:assembleChinaDebug
```

From the repository root, the configuration tests can run without Pods:

```sh
python3 scripts/validate.py ios --suite spatius-config
python3 scripts/validate.py ios --suite spatius-layout
```

The geometry tests cover phone, tablet, foldable, narrow split and ultrawide viewports, plus Android vertical/horizontal hinges, zero-width folds, multiple hinges and window offsets. These establish layout policy, not GPU output or call continuity.

Install iOS dependencies with `pod install`, or `pod update AvatarKitRTC AvatarKitAgoraBridge agent-client-toolkit-swift ConvoAI IoT --no-repo-update` when migrating an existing lockfile. Once the domestic Pods are installed, include `ShengwangRtcEngine_iOS` or `ShengWang-Rtm` when changing their versions. Set `SKIP_DEMO_RESOURCE_DOWNLOAD=1` only when the demo resources already exist locally. Build the `Agent-cn` workspace scheme. On real arm64 devices, verify first download and cached reconnect, speaking animation with audio and subtitles, camera/transcript window switching, Agent stop on rendering failure, and hangup while downloading followed by immediate retry. During a call, also fold/unfold, enter split-window mode, resize the window, and move the floating view before shrinking its parent. Check head/shoulder framing, pane containment, and usable hangup. Automated tests do not validate GPU rendering or a live Spatius call.
