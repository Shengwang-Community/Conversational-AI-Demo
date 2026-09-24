# Spatius compatibility with Shengwang RTC 4.6.4

This integration uses AvatarKitRTC 1.0.1 from upstream commit
`f4548dffdec3f9a248a3193dfbf87320e33e4d0a` in
https://github.com/spatius-ai/avatarkit-ios-rtc.

Upstream pins both RTC-related Pods to AgoraRtcEngine_iOS 4.5.2. The domestic
Demo uses ShengwangRtcEngine_iOS 4.6.4, which changes the native encoded-video
observer signature. The Swift module remains AgoraRtcKit. These local
overrides keep that compatibility change reproducible after `pod install`:

- `AvatarKitRTC.podspec.json` fetches the unchanged upstream Swift source and
  replaces that dependency with ShengwangRtcEngine_iOS 4.6.4. Its other
  dependencies and version are unchanged.
- `AvatarKitAgoraBridge` contains the upstream header and Objective-C++ relay.
  The relay adds the leading `const char *channelId` argument required by the
  RTC 4.6.4 interface. Data, UID and timestamp forwarding, buffer copying, and
  observer registration/cleanup preserve upstream behavior. The callback's
  `override` qualifier makes a future native signature mismatch a build error.
- The local bridge podspec requires ShengwangRtcEngine_iOS 4.6.4 and points to
  these local sources.

The host uses one channel per engine. The bridge preserves upstream behavior
and does not forward the new channel ID into Swift. Multi-channel avatar
rendering requires a separate routing change.

Do not patch the generated `Pods` directory or remove the exact RTC constraint
without validating the bridge against the selected SDK headers. Replace these
overrides when an upstream release supports RTC 4.6.4 and has been validated.

The vendored bridge and upstream Swift adapter retain the Spatius commercial
license declared in their podspecs: Copyright © 2026 Spatius. All rights
reserved. Use is subject to the Spatius commercial license agreement.
