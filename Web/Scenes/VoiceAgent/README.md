# 🌟 声网对话式 AI 引擎体验应用

声网对话式 AI 引擎重新定义了人机交互界面，突破了传统文字交互，实现了高拟真、自然流畅的实时语音对话，让 AI 真正"开口说话"。适用于创新场景如：

- 🤖 智能助手
- 💞 情感陪伴
- 🗣️ 口语陪练
- 🎧 智能客服
- 📱 智能硬件
- 🎮 沉浸式游戏 NPC

## 🚀 一、快速开始

这个部分主要介绍如何快速跑通声网对话式 AI 引擎体验应用项目。

### 💻 1.1 环境准备

- 安装 nodejs 22+和 git

```bash
# Linux/MacOS 可以直接在终端执行
# Windows 建议使用 Windows WSL
# https://github.com/nvm-sh/nvm?tab=readme-ov-file#install--update-script
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# 安装nodejs 22+
nvm install 22
nvm use 22

# 安装git (MacOS 自带git,无需安装)
# Debian/Ubuntu
sudo apt install git-all

# Fedora/RHEL/CentOS
sudo dnf install git-all
```

### ⚙️ 1.2 运行项目

#### 1.2.1 获取 APP ID 和 APP 证书

- 进入[声网控制台](https://console.shengwang.cn/overview)
- 点击创建项目
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_1.jpg)
- 选择项目基础配置，鉴权机制需要选择**安全模式**
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_2.jpg)
- 获取项目 APP ID 与 APP 证书

#### 1.2.2 开启对话式 AI 引擎功能权限

- 在[声网控制台](https://console.shengwang.cn/product/ConversationAI?tab=config)开启权限
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/ConvoAI.png)

#### 1.2.3 获取 RESTful API 密钥

- 在[声网控制台](https://console.shengwang.cn/settings/restfulApi)点击添加密钥
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/restful.png)
- 下载密钥文件，复制 BASIC_AUTH_KEY 和 BASIC_AUTH_SECRET

#### 1.2.4 获取 LLM 配置信息

- 自行在 LLM 厂商官网获取相关配置信息

#### 1.2.5 获取 TTS 配置信息

- 自行在 TTS 厂商官网获取相关配置信息

#### 1.2.6 配置项目

- 安装依赖

```bash
# 使用你喜爱的包管理器安装依赖 npm/yarn/pnpm/bun
# 使用npm 安装
npm i
# 使用yarn 安装
# npm install -g yarn
yarn
# 使用pnpm 安装
# npm install -g pnpm
pnpm i
# 使用bun 安装
# npm install -g bun
bun i
```

- 设置环境变量

```bash
cp .env.example .env.local
```

```
#----------- AppId --------------
AGORA_APP_ID=<声网 App ID>
AGORA_APP_CERT=<声网 App Certificate>

#----------- Basic Auth ---------------
AGENT_BASIC_AUTH_KEY=<声网 RESTful API KEY>
AGENT_BASIC_AUTH_SECRET=<声网 RESTful API SECRET>

#----------- LLM -----------
NEXT_PUBLIC_CUSTOM_LLM_URL="<your-LLM-url>"
NEXT_PUBLIC_CUSTOM_LLM_KEY="<your-LLM-key>"
NEXT_PUBLIC_CUSTOM_LLM_SYSTEM_MESSAGES="<your-TTS-vendor>"
NEXT_PUBLIC_CUSTOM_LLM_MODEL="<your-LLM-model>"

#----------- TTS -----------
NEXT_PUBLIC_CUSTOM_TTS_VENDOR="<your-TTS-vendor>"
NEXT_PUBLIC_CUSTOM_TTS_PARAMS="<your-TTS-params>"
```

- 本地运行

```bash
bun dev
```

## 🗂️ 项目结构导览

| 路径                                          | 描述                               |
| -------------------------------------------- | -------------------------------- |
| [api/](./src/app/api/)                       | 对话式 AI 引擎 API 接口实现和数据模型 |
| [app/page](./src/app/page.tsx)               | 页面主要内容                       |
| [components/](./src/components/)             | 页面组件                          |
| [logger/](./src/lib/logger)                  |日志处理                           |
| [services/rtc](./src/services/rtc.ts)        | RTC 音视频通信相关实现              |
| [type/rtc](./src/type/rtc.ts)                |  RTC的类型和枚举  |

## 📚 三、相关资源

- 📖 查看我们的 [对话式 AI 引擎文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page) 了解更多详情
- 🧩 访问 [Agora SDK 示例](https://github.com/AgoraIO) 获取更多教程和示例代码
- 👥 在 [Agora 开发者社区](https://github.com/AgoraIO-Community) 探索开发者社区管理的优质代码仓库
- 💬 如有疑问，欢迎在 [Stack Overflow](https://stackoverflow.com/questions/tagged/agora.io) 提问

## 💡 四、问题反馈

如果您在集成过程中遇到任何问题或有改进建议：

- 🤖 可通过[声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=)获取智能客服帮助或联系技术支持人员
- ✉️ 发送邮件至 [support@agora.io](mailto:support@agora.io) 获取专业支持

## 📜 五、许可证

本项目采用 MIT 许可证 (The MIT License)。
