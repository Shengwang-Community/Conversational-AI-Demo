# ConversationalAI API (Web)

> Version: 2.0.2

## Prerequisites

- Agora RTC SDK version **4.23.4** or above
- Agora RTM SDK integrated and logged in

**Important:**

> Users need to integrate and manage the initialization, lifecycle, and login status of RTC and RTM by themselves.
>
> Please ensure that the lifecycle of RTC and RTM instances is greater than the lifecycle of this component.
>
> Before using this component, please ensure that RTC is available and RTM is logged in.

---

## File Structure

```
conversational-ai-api/
├── index.ts              # API entry, ConversationalAIAPI class
├── type.ts               # Interfaces, data structures and enums
├── utils/
│   ├── index.ts          # Utility functions
│   ├── event.ts          # Event helper base class
│   ├── logger.ts         # Logger utility
│   └── sub-render.ts     # Subtitle render controller
├── helper/               # !! DO NOT COPY - Demo only !!
│   ├── rtc.ts            # RTC helper (demo-specific)
│   ├── rtm.ts            # RTM helper (demo-specific)
│   └── transcript.ts     # Transcript helper (demo-specific)
└── README.md
```

### About `helper/`

The `helper/` directory contains RTC/RTM wrapper classes used **only by this demo application**. These files are tightly coupled to the demo's specific business logic and should **NOT** be copied into your project. You should implement your own RTC/RTM initialization and lifecycle management according to your application's needs.

---

## Integration Steps

1. Copy the following files into your project:

   - `index.ts`
   - `type.ts`
   - `utils/index.ts`
   - `utils/event.ts`
   - `utils/logger.ts`
   - `utils/sub-render.ts`

2. Update import paths as needed (e.g. the logger import uses a relative path `../utils/logger`).

3. Ensure your project has Agora RTC (>= 4.23.4) and RTM SDKs installed.

---

## Quick Start

### 1. Enable RTC Private Parameters (Required)

Before creating an RTC client, you **must** enable PTS metadata:

```typescript
AgoraRTC.setParameter("ENABLE_AUDIO_PTS_METADATA", true);

const client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
```

### 2. Initialize

```typescript
import { ConversationalAIAPI } from "./conversational-ai-api";
import { ETranscriptHelperMode } from "./conversational-ai-api/type";

const conversationalAIAPI = ConversationalAIAPI.init({
  rtcEngine: rtcClient,
  rtmEngine: rtmClient,
  enableLog: true,
  // Optional: specify render mode, defaults to auto-detect (UNKNOWN)
  renderMode: ETranscriptHelperMode.WORD,
  // Optional: enable fallback to TEXT mode when WORD data is missing (default: true)
  enableRenderModeFallback: true,
});
```

### 3. Register Event Callbacks

```typescript
import { EConversationalAIAPIEvents } from "./conversational-ai-api/type";

conversationalAIAPI.on(
  EConversationalAIAPIEvents.TRANSCRIPT_UPDATED,
  (chatHistory) => {
    // chatHistory is the complete conversation list, render UI based on this
  }
);

conversationalAIAPI.on(
  EConversationalAIAPIEvents.AGENT_STATE_CHANGED,
  (agentUserId, event) => {
    console.log(`Agent ${agentUserId} state: ${event.state}`);
  }
);

conversationalAIAPI.on(
  EConversationalAIAPIEvents.AGENT_INTERRUPTED,
  (agentUserId, event) => {
    console.log(`Agent ${agentUserId} interrupted at turn ${event.turnID}`);
  }
);

conversationalAIAPI.on(
  EConversationalAIAPIEvents.AGENT_METRICS,
  (agentUserId, metrics) => {
    console.log(`Agent ${agentUserId} metrics:`, metrics);
  }
);

conversationalAIAPI.on(
  EConversationalAIAPIEvents.AGENT_ERROR,
  (agentUserId, error) => {
    console.error(`Agent ${agentUserId} error:`, error);
  }
);
```

### 4. Subscribe to Channel Messages

Call before starting the session:

```typescript
conversationalAIAPI.subscribeMessage(channelName);
```

### 5. Send Messages (Optional)

```typescript
// Send text
await conversationalAIAPI.chat(agentUserId, {
  messageType: EChatMessageType.TEXT,
  text: "Hello",
  priority: EChatMessagePriority.HIGH,
  responseInterruptable: true,
});

// Interrupt agent
await conversationalAIAPI.interrupt(agentUserId);
```

### 6. Cleanup

```typescript
// Unsubscribe from channel
conversationalAIAPI.unsubscribe();

// Destroy instance
conversationalAIAPI.destroy();
```

---

## Configuration Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `rtcEngine` | `IAgoraRTCClient` | (required) | Agora RTC client instance |
| `rtmEngine` | `RTMClient` | (required) | Agora RTM client instance |
| `renderMode` | `ETranscriptHelperMode` | `UNKNOWN` | Transcript render mode (`WORD`, `TEXT`, `CHUNK`, or `UNKNOWN` for auto-detect) |
| `enableLog` | `boolean` | `false` | Enable internal debug logging |
| `enableRenderModeFallback` | `boolean` | `true` | When in WORD mode, automatically fall back to TEXT mode if word-level data is missing |

---

## Notes

- **TRANSCRIPT_UPDATED** callbacks return the **complete** conversation list each time. Render your UI based on this full list rather than incremental updates.
- When `renderMode` is set to `UNKNOWN`, the mode is automatically determined by the first agent message received.
- When `enableRenderModeFallback` is `true` and the mode is `WORD`, if an agent message arrives without word-level timing data, the controller will automatically fall back to `TEXT` mode for the remainder of the session.
