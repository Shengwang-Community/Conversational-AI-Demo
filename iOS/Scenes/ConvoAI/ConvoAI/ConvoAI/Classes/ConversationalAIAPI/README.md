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

   - [ConversationalAIAPI](./) (entire folder)

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

   Implement and add event callbacks to receive AI agent events and transcript content:
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

8. **Unsubscribe**
```swift
    convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
        
    }
```

9. **Destroy API Instance**

   ```swift
    convoAIAPI.destroy()
   ```
---

## Send Image Message

Use the sendImage interface to send an image message to the AI agent:
```swift
let uuid = UUID().uuidString
let imageUrl = "https://example.com/image.jpg"
let message = ImageMessage(uuid: uuid, url: imageUrl)
self.convoAIAPI.chat(agentUserId: "\(agentUid)", message: message) { [weak self] error in
    if let error = error {
        print("send image failed, error: \(error.message)")
    } else {
        print("send image success")
    }
}
```

## Processing Image Sending Status

The actual success or failure status of image sending is confirmed through the following two callbacks:

1. **Image Sending Success - onMessageReceiptUpdated**
When receiving the onMessageReceiptUpdated callback, follow these steps to confirm the image sending status:
```swift
struct PictureInfo: Codable {
    let uuid: String
}

public func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
      if messageReceipt.type == .context {
          guard let messageData = messageReceipt.message.data(using: .utf8) else {
              return
          }
          
          do {
              let imageInfo = try JSONDecoder().decode(PictureInfo.self, from: messageData)
              let uuid = imageInfo.uuid
              // Update UI
              self.messageView.viewModel.updateImageMessage(uuid: uuid, state: .success)
          } catch {
              print("Failed to decode PictureInfo: \(error)")
          }

        print("Failed to parse message string from image info message")
        return
    }
      
  }
```

2. **Image Sending Failure - onMessageError**
```swift
struct ImageUploadError: Codable {
    let code: Int
    let message: String
}

struct ImageUploadErrorResponse: Codable {
    let uuid: String
    let success: Bool
    let error: ImageUploadError?
}

public func onMessageError(agentUserId: String, error: MessageError) {
    if let messageData = error.message.data(using: .utf8) {
        do {
            let errorResponse = try JSONDecoder().decode(ImageUploadErrorResponse.self, from: messageData)
            if !errorResponse.success {
                let errorMessage = errorResponse.error?.message ?? "Unknown error"
                let errorCode = errorResponse.error?.code ?? 0
                
                addLog("<<< [ImageUploadError] Image upload failed: \(errorMessage) (code: \(errorCode))")
                
                // Update UI to show error state
                DispatchQueue.main.async { [weak self] in
                    self?.messageView.viewModel.updateImageMessage(uuid: errorResponse.uuid, state: .failed)
                }
            }
        } catch {
            addLog("<<< [onMessageError] Failed to parse error message JSON: \(error)")
        }
    }
}
```

## Notes
- **Subscribe to Channel Messages**
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

- **Unsubscribe**
  Call at the end of each session:
   ```swift
    convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
        
    }
  ```
  
- **Audio Settings:**
  Before joining the RTC channel each time, you must call `loadAudioSettings()` to ensure optimal AI conversation audio quality.
  ```swift
    convoAIAPI.loadAudioSettings()
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
  ```
- **Avatar Audio Settings：**
If the avatar feature is enabled, the `.default` audio scene must be used to achieve optimal audio mixing effects.：
  ```swift
    // Correct audio settings when enabling avatar
    convoAIAPI.loadAudioSettings(secnario: .default)
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
  ```

Audio settings recommendations for different scenarios:
- **Avatar mode**：`.default` - Deliver better audio mixing results
- **Standard Mode**：`.aiClient` - Applicable to standard AI dialogue scenarios

- **All event callbacks are executed on the main thread.**
  You can safely update the UI directly in callbacks.

---

## File Structure

- [ConversationalAIAPI.swift](./ConversationalAIAPI.swift) — API interfaces and related data structures and enums
- [ConversationalAIAPIImpl.swift](./ConversationalAIAPIImpl.swift) — ConversationalAI API main implementation logic
- [Transcript/](./Transcript/)
  - [TranscriptController.swift](./Transcript/TranscriptController.swift) — Subtitle controller

> The above files and folders are all the content needed to integrate ConversationalAI API, no need to copy other files.

---

## Support

- Get help through [Agora Support](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) for intelligent customer service or contact technical support staff
