# ConversationalAI API for Android

**重要说明：**
> 用户需自行集成并管理 RTC、RTM 的初始化、生命周期和登录状态。
>
> 请确保 RTC、RTM 实例的生命周期大于本组件的生命周期。
>
> 在使用本组件前，请确保 RTC 可用，RTM 已登录。
>
> 本组件默认你已在项目中集成了 Agora RTC/RTM，且 RTC SDK 版本需为 **4.5.1 及以上**。
>
> ⚠️ 使用本组件前，必须在声网控制台开通"实时消息 RTM"功能，否则组件无法正常工作。
>
> RTM 接入指南：[RTM](https://doc.shengwang.cn/doc/rtm2/android/landing-page)

![在声网控制台开通 RTM 功能](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)
*截图：在声网控制台项目设置中开通 RTM 功能*

---

## 集成步骤

1. 将以下文件和文件夹拷贝到你的 Android 项目中：
   - [subRender/v3/](./subRender/v3/)（v3整个文件夹）
   - [ConversationalAIAPIImpl.kt](./ConversationalAIAPIImpl.kt)
   - [IConversationalAIAPI.kt](./IConversationalAIAPI.kt)
   - [ConversationalAIUtils.kt](./ConversationalAIUtils.kt)

   > ⚠️ 请保持包名结构（`io.agora.scene.convoai.convoaiApi`）不变，以保证组件正常集成。

2. 确保你的项目已集成 Agora RTC/RTM，且 RTC 版本为 **4.5.1 及以上**。

---

## 快速开始

请按以下步骤快速集成和使用 ConversationalAI API：

1. **初始化 API 配置**

   使用你的 RTC 和 RTM 实例创建配置对象：
   ```kotlin
   val config = ConversationalAIAPIConfig(
       rtcEngine = rtcEngineInstance,
       rtmClient = rtmClientInstance,
       renderMode = TranscriptionRenderMode.Word, // 或 TranscriptionRenderMode.Text
       enableLog = true
   )
   ```

2. **创建 API 实例**

   ```kotlin
   val api = ConversationalAIAPIImpl(config)
   ```

3. **注册事件回调**

   实现并添加事件回调，接收 AI agent 事件和转录内容：
   ```kotlin
   api.addHandler(object : IConversationalAIAPIEventHandler {
       override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) { /* ... */ }
       override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) { /* ... */ }
       override fun onAgentMetrics(agentUserId: String, metric: Metric) { /* ... */ }
       override fun onAgentError(agentUserId: String, error: ModuleError) { /* ... */ }
       override fun onMessageError(agentUserId: String, error: MessageError) { /* ... */ }
       override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) { /* ... */ }
       override fun onTranscriptionUpdated(agentUserId: String, transcription: Transcription) { /* ... */ }
       override fun onDebugLog(log: String) { /* ... */ }
   })
   ```

4. **订阅频道消息**

   在开始会话前调用：
   ```kotlin
   api.subscribeMessage("channelName") { error ->
       if (error != null) {
           // 处理错误
       }
   }
   ```

5. **（可选）加入 RTC 频道前设置音频参数**

   ```kotlin
   api.loadAudioSettings()
   rtcEngine.joinChannel(token, channelName, null, userId)
   ```

6. **（可选 发送消息给 AI agent**

   **发送文本消息：**
   ```kotlin
   // 基本文本消息
   api.chat("agentUserId", TextMessage(text = "Hello, how are you?")) { error ->
       if (error != null) {
           Log.e("Chat", "Failed to send text: ${error.errorMessage}")
       }
   }
   
   // 带优先级控制的文本消息
   api.chat("agentUserId", TextMessage(
       text = "Urgent question!",
       priority = Priority.INTERRUPT,
       responseInterruptable = true
   )) { error ->
       if (error != null) {
           Log.e("Chat", "Failed to send text: ${error.errorMessage}")
       }
   }
   ```

   **发送图片消息：**
   ```kotlin
   val uuid = "unique-image-id-123" // 生成唯一的图片标识符
   val imageUrl = "https://example.com/image.jpg" // 图片的 HTTP/HTTPS URL
   
   api.chat("agentUserId", ImageMessage(uuid = uuid, imageUrl = imageUrl)) { error ->
       if (error != null) {
           Log.e("Chat", "Failed to send image: ${error.errorMessage}")
       } else {
           Log.d("Chat", "Image send request successful")
       }
   }
   ```

7. **（可选）打断 agent**

   ```kotlin
   api.interrupt("agentId") { error -> /* ... */ }
   ```

8. **销毁 API 实例**

   ```kotlin
   api.destroy()
   ```

---

## 消息类型说明

### 文本消息 (TextMessage)

文本消息适用于自然语言交互：

```kotlin
// 文本消息
val textMessage = TextMessage(text = "Hello, how are you?")
```

### 图片消息 (ImageMessage)

图片消息适用于视觉内容处理，通过 `uuid` 进行状态跟踪：

```kotlin
// 使用图片 URL
val urlImageMessage = ImageMessage(
    uuid = "img_123",
    imageUrl = "https://example.com/image.jpg"
)

// 使用 Base64 编码（注意 32KB 限制）
val base64ImageMessage = ImageMessage(
    uuid = "img_456",
    imageBase64 = "data:image/jpeg;base64,..."
)
```

### 发送消息

使用统一的 `chat` 接口发送不同类型的消息：

```kotlin
// 发送文本消息
api.chat("agentUserId", TextMessage(text = "Hello, how are you?")) { error ->
    if (error != null) {
        Log.e("Chat", "Failed to send text: ${error.errorMessage}")
    }
}

// 发送图片消息
api.chat("agentUserId", ImageMessage(uuid = "img_123", imageUrl = "https://...")) { error ->
    if (error != null) {
        Log.e("Chat", "Failed to send image: ${error.errorMessage}")
    }
}
```

### 处理图片发送状态

图片发送的实际成功或失败状态通过以下两个回调来确认：

#### 1. 图片发送成功 - onMessageReceiptUpdated

当收到 `onMessageReceiptUpdated` 回调时，可以通过以下方式确认图片发送状态：

```kotlin
override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
    if (receipt.chatMessageType == ChatMessageType.Image) {
        try {
            val json = JSONObject(receipt.message)
            if (json.has("uuid")) {
                val receivedUuid = json.getString("uuid")
                
                // 如果 uuid 匹配，说明此图片发送成功
                if (receivedUuid == "your-sent-uuid") {
                    Log.d("ImageSend", "Image sent successfully: $receivedUuid")
                    // 更新 UI 显示发送成功状态
                }
            }
        } catch (e: Exception) {
            Log.e("ImageSend", "Failed to parse message receipt: ${e.message}")
        }
    }
}
```

#### 2. 图片发送失败 - onMessageError

当收到 `onMessageError` 回调时，可以通过以下方式确认图片发送失败：

```kotlin
override fun onMessageError(agentUserId: String, error: MessageError) {
    if (error.chatMessageType == ChatMessageType.Image) {
        try {
            val json = JSONObject(error.message)
            if (json.has("uuid")) {
                val failedUuid = json.getString("uuid")

                // 如果 uuid 匹配，说明此图片发送失败
                if (failedUuid == "your-sent-uuid") {
                    Log.e("ImageSend", "Image send failed: $failedUuid")
                    // 更新 UI 显示发送失败状态
                }
            }
        } catch (e: Exception) {
            Log.e("ImageSend", "Failed to parse error message: ${e.message}")
        }
    }
}
```

---

## 注意事项

- **音频设置：**
  每次加入 RTC 频道前，必须调用 `loadAudioSettings()`，以保证 AI 会话音质最佳。
  ```kotlin
  api.loadAudioSettings()
  rtcEngine.joinChannel(token, channelName, null, userId)
  ```

- **所有事件回调均在主线程执行。**
  可直接在回调中安全更新 UI。

- **消息发送状态确认：**
  - `chat` 接口的 completion 回调仅表示发送请求是否成功，不代表消息实际处理状态
  - 图片消息的实际发送成功通过 `onMessageReceiptUpdated` 回调确认
  - 图片消息的发送失败通过 `onMessageError` 回调确认
  - 推荐使用 `sou` 字段进行快速判断，性能更好

- **图片消息状态跟踪：**
  - 直接检查 `chatMessageType == ChatMessageType.Image`
  - 通过解析 JSON 中的 `uuid` 字段确认具体图片的发送状态

---

## 文件结构

- [IConversationalAIAPI.kt](./IConversationalAIAPI.kt) — API 接口及相关数据结构和枚举
- [ConversationalAIAPIImpl.kt](./ConversationalAIAPIImpl.kt) — ConversationalAI API 主要实现逻辑
- [ConversationalAIUtils.kt](./ConversationalAIUtils.kt) — 工具函数与事件回调管理
- [subRender/](./subRender/)
  - [v3/](./subRender/v3/) — 字幕部分模块
    - [TranscriptionController.kt](./subRender/v3/TranscriptionController.kt)
    - [MessageParser.kt](./subRender/v3/MessageParser.kt)

> 以上文件和文件夹即为集成 ConversationalAI API 所需全部内容，无需拷贝其他文件。

---

## 问题反馈

- 可通过 [声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) 获取智能客服帮助或联系技术支持人员