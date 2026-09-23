# Web Toolkit 接入

当前 Demo 精确依赖公开 npm 包 `agora-agent-client-toolkit@2.10.0`。公共 API、状态、字幕和 metrics 协议解析由 Toolkit 维护。

## 安装

在 `Web/Scenes/VoiceAgent` 执行 `bun install --frozen-lockfile`。在自己的应用中可使用：

```bash
npm install --save-exact agora-agent-client-toolkit@2.10.0
```

RTC SDK 需要 `>=4.23.4`；此 Demo 同时使用已登录的 RTM SDK（`>=2.0.0`）。Toolkit 接收应用创建的 RTC/RTM 实例；音频采集、设备管理和登录由应用负责。

## 初始化、事件和清理

在浏览器客户端中创建 RTC、登录 RTM 后，等待 Toolkit 初始化完成，再绑定事件、订阅频道，并启动 Agent。以下变量 `rtcClient`、`rtmClient`、`channelName` 由应用提供：

```typescript
import {
  ConversationalAIAPI,
  EConversationalAIAPIEvents,
  ETranscriptHelperMode
} from 'agora-agent-client-toolkit'

// rtcClient is already created; rtmClient is already logged in.
const api = await ConversationalAIAPI.init({
  rtcEngine: rtcClient,
  rtmEngine: rtmClient,
  renderMode: ETranscriptHelperMode.TEXT,
  enableLog: false
})

api.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (history) => {
  console.log(history)
})
api.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (uid, event) => {
  console.log(uid, event.state)
})
api.on(EConversationalAIAPIEvents.AGENT_TURN_FINISHED, (uid, turn) => {
  console.log(uid, turn.turnId, turn.e2eLatencyMs, turn.segmentedLatency)
})
api.on(EConversationalAIAPIEvents.AGENT_METRICS, (uid, metric) => {
  console.log(uid, metric)
})
api.subscribeMessage(channelName)
```

退出通话时先销毁 Toolkit，再退出 RTC/RTM。初始化失败时也可执行以下清理；重新通话时重新 `await init(...)`：

```typescript
if (ConversationalAIAPI.getState()) {
  ConversationalAIAPI.getInstance().destroy()
}
// Disconnect and release your RTC/RTM clients after Toolkit is destroyed.
```

需要导出调试日志时，可开启 `enableLog` 并订阅 `DEBUG_LOG`，将日志交给应用的日志工具。

## Demo 保留的职责

- `helper/rtc.ts`、`helper/rtm.ts`：RTC/RTM 初始化、登录、采集、设备和连接生命周期。
- `helper/transcript.ts`：旧协议字幕兼容；当前协议使用 Toolkit。
- `utils/event.ts`、`utils/index.ts`：Demo helper 使用的事件和日志格式工具。
- `src/lib/latency-metrics.ts`：已解析 metrics 的 UI 映射、报表组装；`turn.finished` 原始协议由 Toolkit 解析。
- 端上 AINS 由 Demo RTC 层控制，默认关闭，仅开发模式和 AINS 开关同时开启时启用。

`helper/` 与 Demo 业务绑定。集成到自己的应用时，使用 Toolkit 的公共 API，并按自身需求管理 RTC/RTM。

## 验证

`bun run test` 包含真实 npm Toolkit 包的状态、RTC/RTM 字幕、metrics 和销毁后重建验证；传输层使用模拟事件。另执行 `bun run typecheck` 和 `bun run build`，音频效果需要实际通话验证。

[Toolkit 官方文档](https://github.com/AgoraIO-Conversational-AI/agent-client-toolkit-ts#readme)
