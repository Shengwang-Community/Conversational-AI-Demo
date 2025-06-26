# ConversationalAI API for iOS

**Important Notes:**
> Users need to integrate and manage the initialization, lifecycle, and login status of RTC and RTM themselves.
>
> Please ensure that the lifecycle of RTC and RTM instances is longer than the component's lifecycle.
>
> Before using this component, please ensure RTC is available and RTM is logged in.
>
> This component assumes you have integrated Agora RTC/RTM in your project, and the RTC SDK version must be **4.5.1 or above**.
>
> ⚠️ Before using this component, you must enable the "Real-time Messaging RTM" feature in the Agora Console, otherwise the component will not work properly.
>
> RTM Access Guide: [RTM](https://doc.shengwang.cn/doc/rtm2/swift/landing-page)

![Enable RTM feature in Agora Console](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)
*Screenshot: Enable RTM feature in Agora Console project settings*

---

## Integration Steps

1. Copy the following files and folders to your iOS project:
   - [ConversationalAIAPI](./ConversationalAIAPI/) (entire folder)

2. Ensure your project has integrated Agora RTC/RTM, and RTC version is **4.5.1 or above**.

---

## Quick Start

Please follow these steps to quickly integrate and use the ConversationalAI API:

1. **Initialize API Configuration**

   Create a configuration object using your RTC and RTM instances:
   ```swift
    let config = ConversationalAIAPIConfig(
        rtcEngine: rtcEngine, 
        rtmEngine: rtmEngine, 
        renderMode: .words, 
        enableLog: true
    )
   ```

2. **Create API Instance**

   ```swift
    convoAIAPI = ConversationalAIAPIImpl(config: config)
   ```

3. **Register Event Callbacks**

   Implement and add event callbacks to receive AI agent events and transcription content:
   ```swift
   convoAIAPI.addHandler(handler: self)
   ```

4. **Subscribe to Channel Messages**

   Call before starting a session:
   **Must be called after logging in to RTM**
   ```swift
    convoAIAPI.subscribeMessage(channelName: channelName) { error in
        if let error = error {
            print("Subscription failed: \(error.message)")
        } else {
            print("Subscription successful")
        }
    }
   ```

5. **(Optional) Set Audio Parameters Before Joining RTC Channel**

   ```swift
    convoAIAPI.loadAudioSettings()
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
   ```

7. **(Optional) Interrupt Agent**

   ```swift
    convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
        if let error = error {
            print("Interrupt failed: \(error.message)")
        } else {
            print("Interrupt successful")
        }
    }
   ```

8. **Destroy API Instance**

   ```swift
    convoAIAPI.destroy()
   ```
---

## Notes

- **Audio Settings:**
  Before joining the RTC channel each time, you must call `loadAudioSettings()` to ensure optimal AI conversation audio quality.
  ```swift
    convoAIAPI.loadAudioSettings()
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
  ```

- **All event callbacks are executed on the main thread.**
  You can safely update the UI directly in callbacks.

---

## File Structure

- [ConversationalAIAPI.swift](./ConversationalAIAPI.swift) — API interfaces and related data structures and enums
- [ConversationalAIAPIImpl.swift](./ConversationalAIAPIImpl.swift) — ConversationalAI API main implementation logic
- [Transcription/](./Transcription/)
  - [TranscriptionController.swift](./SubRender/TranscriptionController.swift) — Subtitle controller

> The above files and folders are all the content needed to integrate ConversationalAI API, no need to copy other files.

---

## Support

- Get help through [Agora Support](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) for intelligent customer service or contact technical support staff