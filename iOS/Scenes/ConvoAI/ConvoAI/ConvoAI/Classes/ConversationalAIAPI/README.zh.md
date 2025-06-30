# ConversationalAI API for iOS

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
> RTM 接入指南：[RTM](https://doc.shengwang.cn/doc/rtm2/swift/landing-page)

![在声网控制台开通 RTM 功能](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)
*截图：在声网控制台项目设置中开通 RTM 功能*

---

## 集成步骤

1. 将以下文件和文件夹拷贝到你的 iOS 项目中：
   - [ConversationalAIAPI](./)（整个文件夹）

2. 确保你的项目已集成 Agora RTC/RTM，且 RTC 版本为 **4.5.1 及以上**。

---

## 快速开始

请按以下步骤快速集成和使用 ConversationalAI API：

1. **初始化 API 配置**

   使用你的 RTC 和 RTM 实例创建配置对象：
   ```swift
    let config = ConversationalAIAPIConfig(
        rtcEngine: rtcEngine, 
        rtmEngine: rtmEngine, 
        renderMode: .words, 
        enableLog: true
    )
   ```

2. **创建 API 实例**

   ```swift
    convoAIAPI = ConversationalAIAPIImpl(config: config)
   ```

3. **注册事件回调**

   实现并添加事件回调，接收 AI agent 事件和转录内容：
   ```swift
   convoAIAPI.addHandler(handler: self)
   ```

4. **订阅频道消息**

   在开始会话前调用：
   **必须在登录RTM之后调用**
   ```swift
    convoAIAPI.subscribeMessage(channelName: channelName) { error in
        if let error = error {
            print("订阅失败: \(error.message)")
        } else {
            print("订阅成功")
        }
    }
   ```

5. **（可选）加入 RTC 频道前设置音频参数**

   ```swift
    convoAIAPI.loadAudioSettings()
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
   ```

7. **（可选）打断 agent**

   ```swift
    convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
        if let error = error {
            print("打断失败: \(error.message)")
        } else {
            print("打断成功")
        }
    }
   ```
   
8. **取消订阅**
```swift
    convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
        
    }
```

8. **销毁 API 实例**

   ```swift
    convoAIAPI.destroy()
   ```
---

## 注意事项
- **订阅频道消息**
 在开始会话调用：
   **必须在登录RTM之后调用**
   ```swift
    convoAIAPI.subscribeMessage(channelName: channelName) { error in
        if let error = error {
            print("订阅失败: \(error.message)")
        } else {
            print("订阅成功")
        }
    }
   ```

- **取消订阅**
  每次结束会话调用：
   ```swift
    convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
        
    }
  ```
  
- **音频设置：**
  每次加入 RTC 频道前，必须调用 `loadAudioSettings()`，以保证 AI 会话音质最佳。
  ```swift
    convoAIAPI.loadAudioSettings()
    rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)
  ```

- **所有事件回调均在主线程执行。**
  可直接在回调中安全更新 UI。

---

## 文件结构

- [ConversationalAIAPI.swift](./ConversationalAIAPI.swift) — API 接口及相关数据结构和枚举
- [ConversationalAIAPIImpl.swift](./ConversationalAIAPIImpl.swift) — ConversationalAI API 主要实现逻辑
- [Transcription/](./Transcription/)
  - [TranscriptionController.swift](./Transcription/TranscriptionController.swift) — 字幕控制器

> 以上文件和文件夹即为集成 ConversationalAI API 所需全部内容，无需拷贝其他文件。

---

## 问题反馈

- 可通过 [声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) 获取智能客服帮助或联系技术支持人员
