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

- 最低兼容 Android 7.0（SDK API Level 24）
- Android Studio 3.5 及以上版本
- Android 7.0 及以上的手机设备

### ⚙️ 1.2 运行项目

#### 1.2.1 获取 APP ID 和 APP 证书

- 进入 [声网控制台](https://console.shengwang.cn/overview)
- 点击创建项目
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_1.jpg)
- 选择项目基础配置，鉴权机制需要选择**安全模式**
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_2.jpg)
- 获取项目 APP ID 与 APP 证书

#### 1.2.2 开通 RTM 权限

![在声网控制台开通 RTM 功能](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_7.jpg)
*截图：在声网控制台项目设置中开通 RTM 功能*

#### 1.2.3 开启对话式 AI 引擎功能权限

- 在 [声网控制台](https://console.shengwang.cn/product/ConversationAI?tab=config) 开启权限
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/ConvoAI.png)

#### 1.2.4 获取 RESTful API 密钥

- 在 [声网控制台](https://console.shengwang.cn/settings/restfulApi) 点击添加密钥
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/restful.png)
- 下载密钥文件，复制 BASIC_AUTH_KEY 和 BASIC_AUTH_SECRET

#### 1.2.5 获取 LLM 配置信息

- 自行在 LLM 厂商官网获取相关配置信息

#### 1.2.6 获取 TTS 配置信息

- 自行在 TTS 厂商官网获取相关配置信息

#### 1.2.7 配置项目

- 在项目的 [**gradle.properties**](../../gradle.properties) 里填写必须的配置信息：

```
#----------- AppId --------------
AG_APP_ID=<声网 App ID>
AG_APP_CERTIFICATE=<声网 App Certificate>

#----------- Basic Auth ---------------
BASIC_AUTH_KEY=<声网 RESTful API KEY>
BASIC_AUTH_SECRET=<声网 RESTful API SECRET>

#----------- LLM -----------
LLM_URL=<LLM 厂商的 API BASE URL>
LLM_API_KEY=<LLM 厂商的 API KEY>(可选)
LLM_PARRAMS=<LLM 厂商参数>(可选)
LLM_SYSTEM_MESSAGES=<LLM Prompt>(可选)

#----------- TTS -----------
TTS_VENDOR=<TTS 厂商>
TTS_PARAMS=<TTS 参数>

#----------- AVATAR -----------
AVATAR_ENABLE=<是否开启 AVATAR>
AVATAR_VENDOR=<AVATAR 厂商>
AVATAR_PARAMS=<AVATAR 参数>
```

- 用 Android Studio 运行项目即可开始您的体验

## 🗂️ 二、项目结构导览

### 2.1 基本结构
| 路径                                                                                    | 描述                          |
|---------------------------------------------------------------------------------------|-----------------------------|
| [api/](src/main/java/io/agora/scene/convoai/api)                                      | 对话式 AI 引擎 RESTful 接口实现和数据模型 |
| [animation/](src/main/java/io/agora/scene/convoai/animation)                          | 智能体交互动画效果实现                 |
| [constant/](src/main/java/io/agora/scene/convoai/constant)                            | 常量和枚举类型定义                   |
| [convoaiApi/](src/main/java/io/agora/scene/convoai/convoaiApi/)                       | ConversationalAI组件                  |
| [rtc/](src/main/java/io/agora/scene/convoai/rtc)                                      | RTC 音视频通信相关实现               |
| [rtm/](src/main/java/io/agora/scene/convoai/rtm)                                      | RTM 实时消息相关实现                |
| [ui/](src/main/java/io/agora/scene/convoai/ui)                                        | UI 界面组件和交互页面                |
| [CovLivingActivity.kt](src/main/java/io/agora/scene/convoai/ui/CovLivingActivity.kt)  | AI 对话主交互界面                  |
| [CovSettingsDialog.kt](src/main/java/io/agora/scene/convoai/ui/CovSettingsDialog.kt)  | 智能体参数配置设置对话框                |
| [CovAgentInfoDialog.kt](src/main/java/io/agora/scene/convoai/ui/CovAgentInfoDialog.kt) | 智能体运行状态信息展示对话框              |

### 2.2 实时字幕
与对话式智能体进行实时互动时，你可能需要实时字幕显示你与智能体的对话内容。
- 📖 查看我们的 [实时字幕功能指南](https://doc.shengwang.cn/doc/convoai/restful/user-guides/realtime-sub) 了解如何实现该功能
- 实现该功能请参考 [convoaiApi 目录下的 README.md](src/main/java/io/agora/scene/convoai/convoaiApi/README.md) 进行集成
- ⚠️ 开源字幕处理模块由 Kotlin 语言开发，如果您的项目是纯 Java 项目，您可以参考 Google 官方文档 [将 Kotlin 添加到现有应用](https://developer.android.com/kotlin/add-kotlin?hl=zh-cn) 把对应文件集成进您的项目

## 📚 三、相关资源

- 📖 查看我们的 [对话式 AI 引擎文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page) 了解更多详情
- 🧩 访问 [Agora SDK 示例](https://github.com/AgoraIO) 获取更多教程和示例代码
- 👥 在 [Agora 开发者社区](https://github.com/AgoraIO-Community) 探索开发者社区管理的优质代码仓库

## 💡 四、问题反馈

如果您在集成过程中遇到任何问题或有改进建议：

- 🤖 可通过 [声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) 获取智能客服帮助或联系技术支持人员

## 📜 五、许可证

本项目采用 MIT 许可证 (The MIT License)。
