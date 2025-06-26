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
   - [subRender/v3/](./subRender/v3/)（整个文件夹）
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

6. **发送消息给 AI agent**

   ```kotlin
   api.chat(
       agentUserId = "agentId",
       message = ChatMessage(
           priority = Priority.INTERRUPT,
           responseInterruptable = true,
           text = "你好！"
       )
   ) { error ->
       if (error != null) {
           // 处理错误
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

## 注意事项

- **音频设置：**
  每次加入 RTC 频道前，必须调用 `loadAudioSettings()`，以保证 AI 会话音质最佳。
  ```kotlin
  api.loadAudioSettings()
  rtcEngine.joinChannel(token, channelName, null, userId)
  ```

- **所有事件回调均在主线程执行。**
  可直接在回调中安全更新 UI。

- **部分回调（如 `onTranscriptionUpdated`）可能高频触发。**
  如有需要，请在业务层自行去重或限流。

- **错误处理：**
  所有 API 方法均有错误回调，请务必处理 error。

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