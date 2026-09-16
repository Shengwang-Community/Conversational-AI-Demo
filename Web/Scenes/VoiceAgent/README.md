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

### 💻 1.1 环境准备

- 安装 Node.js 22+、Git 和 Bun 1.4.0。

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

- 进入 [声网控制台](https://console.shengwang.cn/overview)
- 点击创建项目
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_1.jpg)
- 选择项目基础配置，鉴权机制需要选择**安全模式**
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/sdhy_2.jpg)
- 获取项目 APP ID 与 APP 证书

#### 1.2.2 开启对话式 AI 引擎功能权限

- 在 [声网控制台](https://console.shengwang.cn/product/ConversationAI?tab=config) 开启权限
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/ConvoAI.png)

#### 1.2.3 获取 RESTful API 密钥

- 在 [声网控制台](https://console.shengwang.cn/settings/restfulApi) 点击添加密钥
  ![图片](https://accktvpic.oss-cn-beijing.aliyuncs.com/pic/github_readme/ent-full/restful.png)
- 下载密钥文件，复制 BASIC_AUTH_KEY 和 BASIC_AUTH_SECRET

#### 1.2.4 获取 LLM 配置信息

- 自行在 LLM 厂商官网获取相关配置信息

#### 1.2.5 获取 TTS 配置信息

- 自行在 TTS 厂商官网获取相关配置信息

#### 1.2.6 配置项目

- 安装依赖

```bash
# 在仓库根目录执行
cd Web/Scenes/VoiceAgent
npm install -g bun@1.4.0
bun install --frozen-lockfile
```

本项目通过公开 npm 包 `agora-agent-client-toolkit` 接入 Toolkit，版本固定为 `2.10.0`，完整依赖由 `bun.lock` 锁定。安装和构建仅需当前仓库。npm/pnpm 也可解析 `package.json`；项目验证和可复现安装使用 Bun。

依赖安装会同时下载 Toolkit，无需本地 `file:`/`link:` 依赖或预先构建 Toolkit。`src/conversational-ai-api/` 仅保留 Demo helpers 与旧版字幕兼容代码；公共 API 从 `agora-agent-client-toolkit` 导入。

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
NEXT_PUBLIC_CUSTOM_LLM_SYSTEM_MESSAGES="<your-LLM-system-messages>"
NEXT_PUBLIC_CUSTOM_LLM_PARAMS="<your-LLM-params>"

#----------- TTS -----------
NEXT_PUBLIC_CUSTOM_TTS_VENDOR="<your-TTS-vendor>"
NEXT_PUBLIC_CUSTOM_TTS_PARAMS="<your-TTS-params>"
```

- 本地运行

```bash
bun run dev
```

### 1.3 Toolkit 接入与验证

- Toolkit 提供公共 API、状态事件、字幕和 metrics 解析；示例见 [Toolkit 接入说明](src/conversational-ai-api/README.md)。
- Demo 保留 RTC/RTM 初始化、音频采集、legacy 字幕兼容和报表展示/上传。端上 AINS 默认关闭，仅在开发模式和 AINS 开关同时开启时启用。
- 普通通话和 SIP 均等待 Toolkit 异步初始化完成，退出时先销毁 Toolkit，再清理 RTC/RTM。

```bash
bun run test
bun run typecheck
bun run build
bun run start
```

升级 Toolkit 时同时更新精确版本和 `bun.lock`，再执行上述检查。自动构建使用 `bun install --frozen-lockfile`，从公开 npm 下载正式包。

## 🗂️ 项目结构导览

| 路径                                          | 描述                               |
| -------------------------------------------- | -------------------------------- |
| [api/](./src/app/api/)                       | 对话式 AI 引擎 API 接口实现和数据模型 |
| [app/page](./src/app/page.tsx)               | 页面主要内容                       |
| [components/](./src/components/)             | 页面组件                          |
| [logger/](./src/lib/logger)                  |日志处理                           |
| [type/rtc](./src/type/rtc.ts)                |  RTC的类型和枚举  |

## 📚 三、相关资源

- 📖 查看我们的 [对话式 AI 引擎文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page) 了解更多详情
- 🧩 访问 [Agora SDK 示例](https://github.com/AgoraIO) 获取更多教程和示例代码
- 👥 在 [Agora 开发者社区](https://github.com/AgoraIO-Community) 探索开发者社区管理的优质代码仓库

## 💡 四、问题反馈

如果您在集成过程中遇到任何问题或有改进建议：

- 🤖 可通过 [声网支持](https://ticket.shengwang.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) 获取智能客服帮助或联系技术支持人员

## 📜 五、许可证

本项目采用 MIT 许可证 (The MIT License)。
