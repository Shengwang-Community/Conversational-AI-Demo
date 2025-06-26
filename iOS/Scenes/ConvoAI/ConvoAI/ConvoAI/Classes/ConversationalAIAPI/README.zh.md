# ConversationalAI API

**注意**：

用户需要自行维护 RTC、RTM 的初始化、生命周期，以及登录态的逻辑，并且需要确保 RTC、RTM 实例生命周期大于组件生命周期， 在使用组件之前，确保RTC可用, RTM为登录状态。

若未开通RTM，需要前往项目的功能配置中启用"实时消息 RTM"功能
**注: 如果没有启动"实时消息 RTM"功能, 将无法体验组件功能**
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)  

RTM接入指南：https://doc.shengwang.cn/doc/rtm2/swift/landing-page

## 使用步骤

1. 将 ConversationalAIAPI 文件夹以及里面的文件拷贝到你自己的项目中
2. 初始化组件
3. 添加监听
4. 订阅消息
5. 音频设置
6. 实现回调

## 代码实现

### 基本使用

#### 1. 声明属性
在需要实现字幕的 UI 模块中，将组件作为成员属性：

```swift
private var convoAIAPI: ConversationalAIAPI!
```

#### 2. 初始化组件

```swift
let config = ConversationalAIAPIConfig(
    rtcEngine: rtcEngine, 
    rtmEngine: rtmEngine, 
    renderMode: .words, 
    enableLog: true
)
self.convoAIAPI = ConversationalAIAPIImpl(config: config)
```

#### 3. 添加回调监听

```swift
convoAIAPI.addHandler(handler: self)
```

#### 4. 订阅频道消息
每次开启通话的时候订阅频道消息
**注意：必须在登录RTM之后调用**

```swift
convoAIAPI.subscribeMessage(channelName: channelName) { error in
    if let error = error {
        print("订阅失败: \(error.message)")
    } else {
        print("订阅成功")
    }
}
// ...
startAgent()
```

#### 5. 音频设置
**注意：每次加入rtc频道之前调用音频设置：**

```swift
convoAIAPI.loadAudioSettings()

//..
rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)

```

#### 6. 实现回调协议
根据需求，实现 `ConversationalAIAPIEventHandler` 回调协议。

例如字幕协议，组件会通过该回调更新字幕信息：

```swift
extension YourViewController: ConversationalAIAPIEventHandler {
    ///实时字幕更新回调，用于显示 AI 和用户的对话内容。
    func onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
        // 处理字幕更新
    }

    
    ///AI 状态变化回调，包含以下状态：
    ///- `idle` - 空闲状态
    ///- `silent` - 静默状态  
    ///- `listening` - 监听状态
    ///- `thinking` - 思考状态
    ///- `speaking` - 说话状态
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // 处理状态变化
    }

    //...
    //...
}
```

#### 7. 取消订阅消息
每次停止通话的时候，取消订阅消息：

```swift
convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
    if let error = error {
        print("取消订阅失败: \(error.message)")
    } else {
        print("取消订阅成功")
    }
}
// ...
stopAgent()
```

#### 8. 销毁组件
退出当前 UI 模块的时候，销毁组件：

```swift
convoAIAPI.destroy()
// ...
self.navigationController?.popViewController(animated: true)
```

### 高级功能

#### 打断功能
可以通过调用组件 `interrupt` 函数，主动打断 Agent。

**注意**：这里的 `agentUserId` 要求是 agent rtm userId，并且必须全局唯一。

```swift
convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
    if let error = error {
        print("打断失败: \(error.message)")
    } else {
        print("打断成功")
    }
}
```



