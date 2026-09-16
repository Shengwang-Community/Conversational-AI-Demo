# 🌟 Conversational-AI-Demo

声网对话式 AI 引擎重新定义了人机交互界面，突破了传统文字交互，实现了高拟真、自然流畅的实时语音对话，让 AI 真正"开口说话"。适用于创新场景如：

- 🤖 智能助手
- 💞 情感陪伴
- 🗣️ 口语陪练
- 🎧 智能客服
- 📱 智能硬件
- 🎮 沉浸式游戏 NPC

## 🚀 一、快速开始

这个部分主要介绍如何快速跑通声网对话式 AI 引擎体验应用项目。

### 📱 1.1 环境准备

- Xcode 15.0 及以上版本
- iOS 15.0 及以上的手机设备

### ⚙️ 1.2 运行项目

#### 1.2.1 获取 APP ID 和 APP 证书

- 进入 [声网控制台](https://console.shengwang.cn/overview)
- 点击创建项目
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_1.jpg)
- 选择项目基础配置，鉴权机制需要选择**安全模式**
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_2.jpg)
- 获取项目 APP ID 与 APP 证书

#### 1.2.2 开启对话式 AI 引擎功能权限

- 在 [声网控制台](https://console.shengwang.cn/product/ConversationAI?tab=config) 开启权限
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/ConvoAI.png)

### 1.2.3 开启RTM 功能权限
- 在[声网控制台开通 RTM 功能](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)

#### 1.2.4 获取 RESTful API 密钥

- 在 [声网控制台](https://console.shengwang.cn/settings/restfulApi) 点击添加密钥
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/restful.png)
- 下载密钥文件，复制 BASIC_AUTH_KEY 和 BASIC_AUTH_SECRET

#### 1.2.5 获取 LLM 配置信息

- 自行在 LLM 厂商官网获取相关配置信息

#### 1.2.6 获取 TTS 配置信息

- 自行在 TTS 厂商官网获取相关配置信息

#### 1.2.7 配置项目

- 打开 `iOS` 项目，在 [**KeyCenter.swift**](../../Agent/KeyCenter.swift) 文件中填写上述获取的配置信息：

``` Swift
    static var IS_OPEN_SOURCE: Bool = true
    
    #----------- AppId --------------
    static let APP_ID: String = <声网 App ID>
    static let CERTIFICATE: String? = <声网 App Certificate>
    
    #----------- Basic Auth ---------------
    static let BASIC_AUTH_KEY: String = <声网 RESTful API KEY>
    static let BASIC_AUTH_SECRET: String = <声网 RESTful API SECRET>
    
    #----------- LLM -----------
    static let LLM_URL: String = <LLM 厂商的 API BASE URL>
    static let LLM_API_KEY: String? = <LLM 厂商的 API KEY>
    static let LLM_SYSTEM_MESSAGES: String? = <LLM Prompt>
    static let LLM_MODEL: String? = <LLM Model>
    
    #----------- TTS -----------
    static let TTS_VENDOR: String = <TTS 厂商>
    static let TTS_PARAMS: [String : Any] = <TTS 参数>

    #----------- AVATAR -----------
    static let AVATAR_ENABLE: Bool = <是否启用AVATAR功能>
    static let AVATAR_VENDOR: String = <AVATAR 厂商>
    static let AVATAR_PARAMS: [String: Any] = <AVATAR 参数>
```

- 在 iOS 目录执行 `pod install` 后运行项目，即可开始您的体验

## 🗂️ 二、项目结构导览

### 2.1 基本结构

| 路径                                                                                                           | 描述                                      |
| ------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| [AgentManager.swift](ConvoAI/ConvoAI/Classes/Manager/AgentManager.swift)                                              | 对话式 AI 引擎 RESTful 接口实现              |
| [RTCManager.swift](ConvoAI/ConvoAI/Classes/Manager/RTCManager.swift)                                                  | RTC 音视频通信相关实现                       |
| [AgentPreferenceManager.swift](ConvoAI/ConvoAI/Classes/Manager/AgentPreferenceManager.swift)                          | Agent状态管理                              |
| [Main/](ConvoAI/ConvoAI/Classes/Main)                                                                                 | UI 界面组件和交互页面                        |
| [Main/Chat](ConvoAI/ConvoAI/Classes/Main/Chat)                                                                        | 聊天页面的视图及控制器                        |
| [AgentInformationViewController.swift](ConvoAI/ConvoAI/Classes/Main/Setting/VC/AgentInformationViewController.swift)  | 智能体运行状态信息展示对话框                   |
| [AgentSettingViewController.swift](ConvoAI/ConvoAI/Classes/Main/Setting/VC/AgentSettingViewController.swift)          | 智能体参数配置设置对话框                       |
| [Utils/](ConvoAI/ConvoAI/Classes/Utils)                                                                               | 实用工具类和辅助函数                          |
| `agent-client-toolkit-swift`（2.10.1 正式包）                                                                                   | 当前对话式 AI API、状态回调和实时字幕组件       |
| [TranscriptionV1/](ConvoAI/ConvoAI/Classes/Utils/TranscriptionV1)                                                    | Demo 保留的 v1 legacy 字幕实现                 |
| [TranscriptionV2/](ConvoAI/ConvoAI/Classes/Utils/TranscriptionV2)                                                    | Demo 保留的 v2 legacy 字幕实现                 |

### 2.2 实时字幕
与对话式智能体进行实时互动时，你可能需要实时字幕显示你与智能体的对话内容。
- 📖 查看我们的 [实时字幕功能指南](https://doc.shengwang.cn/doc/convoai/restful/user-guides/realtime-sub) 了解如何实现该功能
- 当前 API 和实时字幕由 CocoaPods 组件 `agent-client-toolkit-swift`（2.10.1 正式包） 提供，Swift 模块名为 `AgoraAgentClientToolkit`
- Demo 仍保留 v1、v2 legacy 字幕实现，当前默认流程使用 Toolkit 实现

### 2.3 Toolkit 正式包接入

`iOS/Podfile` 已配置以下发布包依赖，并通过清华 CocoaPods Specs 镜像解析：

```ruby
pod 'agent-client-toolkit-swift', '2.10.1'
pod 'AgoraRtm', '2.2.3', :subspecs => ['RtmKit']
```

首次切换或本地索引尚未更新时，在 Demo 仓库根目录执行：

```bash
cd iOS
pod _1.16.2_ install --repo-update
```

打开 `Agent.xcworkspace` 编译运行。本地和 Jenkins 都通过 CocoaPods 下载正式 XCFramework，无需拉取 Toolkit 源码。

Swift 代码使用 `import AgoraAgentClientToolkit`。Toolkit 无需配置 `:path` 或手动添加 XCFramework；Podfile 中 `ConvoAI`、`Common` 等 Demo 自有模块的 `:path` 配置仍用于加载本仓库业务代码。升级 Toolkit 时同步更新 `iOS/Podfile` 与 `iOS/Scenes/ConvoAI/ConvoAI/ConvoAI.podspec` 中的版本。

Demo 将 AINS 开关传给 `loadAudioSettings(scenario:enableAins:)`，默认关闭，切换音频路由后保持相同选择。

### 2.4 AINS 逻辑测试

`Agent-cnLogicTests` 直接编译 App 使用的 `OnDeviceAins.swift`，验证默认关闭、开发模式开关、参数写入顺序、路由切换后恢复选择和状态重置。该 target 无需启动 App，也无需安装 Pods，可以在 ARM64 iOS 模拟器上运行。

在 `iOS` 目录执行（模拟器名称按本机安装情况调整）：

```bash
xcodebuild -project Agent.xcodeproj -scheme Agent-cnLogicTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Xcode 中也可打开 `Agent.xcodeproj`，选择 `Agent-cnLogicTests` scheme 和可用模拟器，再运行 Test。

`Agent-cnTests` 继续保留 `RTCManagerAinsTests` 和其他 App 集成测试，需要完整 App 及 Pods。当前 Bugly 依赖对 ARM64 模拟器的限制仍适用于这类测试；AINS 逻辑测试不验证真机音效。

## 📚 三、相关资源

- 📖 查看我们的 [对话式 AI 引擎文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page) 了解更多详情
- 🧩 访问 [Agora SDK 示例](https://github.com/AgoraIO) 获取更多教程和示例代码
- 👥 在 [Agora 开发者社区](https://github.com/AgoraIO-Community) 探索开发者社区管理的优质代码仓库

## 💡 四、问题反馈

如果您在集成过程中遇到任何问题或有改进建议：

- 🤖 可通过 [声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) 获取智能客服帮助或联系技术支持人员

## 📜 五、许可证

本项目采用 MIT 许可证 (The MIT License)。


### AI workflow and validation

See [iOS workflow](../../AGENTS.md) and [validation guide](../../docs/VALIDATION.md). From the repository root, run `python3 scripts/validate.py ios --suite ains` for standalone AINS tests; `--list` shows the available suites and their scope is defined in `scripts/workflow.json`.
