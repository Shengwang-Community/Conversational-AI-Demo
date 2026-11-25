# Toolkit 2.11.0 with Shengwang RTC 4.6.4 and RTM 2.3.0

The official `agent-client-toolkit-swift` 2.11.0 podspec depends on
`AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRtm/RtmKit >= 2.2.3`. The domestic
Demo uses `ShengwangRtcEngine_iOS` and `ShengWang-Rtm`. Including the original
Pod dependencies would install duplicate `AgoraRtcKit` and `AgoraRtmKit`
frameworks.

This local podspec keeps the official Toolkit 2.11.0 download URL, binary,
SHA-256 checksum, version, module name, license and other settings unchanged.
It changes only the SDK dependencies:

- `AgoraRtcEngine_iOS >= 4.5.1` becomes `ShengwangRtcEngine_iOS >= 4.5.1`.
  The app and Spatius specs pin the resolved RTC version to 4.6.4.
- `AgoraRtm/RtmKit >= 2.2.3` becomes `ShengWang-Rtm/RtmKit = 2.3.0`.

The Swift modules remain `AgoraRtcKit` and `AgoraRtmKit`; application imports
do not change. The RTC Pod supplies AOSL 1.3.5 through `ShengwangInfra_iOS`,
so the RTM `RtmBasic` subspec must not also be included.

Upstream specification:
https://download.agora.io/cocoapods/Specs/0/9/0/agent-client-toolkit-swift/2.11.0/agent-client-toolkit-swift.podspec.json

Run `pod update AvatarKitRTC AvatarKitAgoraBridge agent-client-toolkit-swift ConvoAI IoT --no-repo-update`
when migrating from the old Pod names. Once installed, include
`ShengwangRtcEngine_iOS` or `ShengWang-Rtm` in updates when changing their
versions. Validate the app build and RTM login,
messaging, transcripts and cleanup on a device when upgrading either SDK.
Remove this override when the official Toolkit spec supports the selected RTM
Pod names.
