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

6. **（可选）发送图片消息**

   ```kotlin
   val uuid = "unique-image-id-123" // 生成唯一的图片标识符
   val imageUrl = "https://example.com/image.jpg" // 图片的 HTTP/HTTPS URL
   
   api.sendImage("agentUserId", uuid, imageUrl) { error ->
       if (error != null) {
           // 处理发送错误
           Log.e("ImageSend", "Failed to send image: ${error.errorMessage}")
       } else {
           // 发送请求成功，等待回执确认
           Log.d("ImageSend", "Image send request successful")
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

## 发送图片消息

### 发送图片

使用 `sendImage` 接口发送图片消息给 AI agent：

```kotlin
val uuid = "unique-image-id-123" // 生成唯一的图片标识符
val imageUrl = "https://example.com/image.jpg" // 图片的 HTTP/HTTPS URL

api.sendImage("agentUserId", uuid, imageUrl) { error ->
    if (error != null) {
        // 处理发送错误
        Log.e("ImageSend", "Failed to send image: ${error.errorMessage}")
    } else {
        // 发送请求成功，等待回执确认
        Log.d("ImageSend", "Image send request successful")
    }
}
```

### 处理图片发送状态

图片发送的实际成功或失败状态通过以下两个回调来确认：

#### 1. 图片发送成功 - onMessageReceiptUpdated

当收到 `onMessageReceiptUpdated` 回调时，需要按以下步骤解析来确认图片发送状态：

**重要：必须先检查 `receipt.type` 是否为 `ModuleType.Context`，然后再检查 `resource_type`**

```kotlin
override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
    // 第一步：检查消息类型是否为 Context
    if (receipt.type == ModuleType.Context) {
        try {
            // 第二步：解析 receipt.message 为 JSON 对象
            val jsonObject = JSONObject(receipt.message)
            
            // 第三步：检查 resource_type 是否为 picture
            if (jsonObject.has("resource_type") && 
                jsonObject.getString("resource_type") == "picture") {
                
                // 第四步：检查是否包含 uuid 字段
                if (jsonObject.has("uuid")) {
                    val receivedUuid = jsonObject.getString("uuid")
                    
                    // 如果 uuid 匹配，说明此图片发送成功
                    if (receivedUuid == "your-sent-uuid") {
                        Log.d("ImageSend", "Image sent successfully: $receivedUuid")
                        // 更新 UI 显示发送成功状态
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("ImageSend", "Failed to parse message receipt: ${e.message}")
        }
    }
}
```

#### 2. 图片发送失败 - onAgentError

当收到 `onAgentError` 回调且 `error.type` 为 `ModuleType.Context` 时，需要解析 `error.message` 来确认图片发送失败：

```kotlin
override fun onAgentError(agentUserId: String, error: ModuleError) {
    // 检查是否为 Context 类型的错误
    if (error.type == ModuleType.Context) {
        try {
            // 解析 error.message 为 JSON 对象
            val jsonObject = JSONObject(error.message)
            
            // 检查 resource_type 是否为 picture
            if (jsonObject.has("resource_type") && 
                jsonObject.getString("resource_type") == "picture") {
                
                // 检查是否包含 uuid 字段
                if (jsonObject.has("uuid")) {
                    val failedUuid = jsonObject.getString("uuid")
                    
                    // 如果 uuid 匹配，说明此图片发送失败
                    if (failedUuid == "your-sent-uuid") {
                        Log.e("ImageSend", "Image send failed: $failedUuid")
                        // 更新 UI 显示发送失败状态
                    }
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

- **图片发送状态确认：**
  - `sendImage` 接口的 completion 回调仅表示发送请求是否成功，不代表图片实际发送状态
  - 实际发送成功通过 `onMessageReceiptUpdated` 回调确认
  - 实际发送失败通过 `onAgentError` 回调确认
  - 需要解析回调中的 JSON 消息来获取具体的 uuid 和状态信息

- **图片消息解析步骤：**
  - **成功回调**：必须先检查 `receipt.type == ModuleType.Context`，然后检查 `resource_type == "picture"`
  - **失败回调**：必须先检查 `error.type == ModuleType.Context`，然后检查 `resource_type == "picture"`
  - 只有满足以上条件后，才能通过 `uuid` 字段确认具体图片的发送状态

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