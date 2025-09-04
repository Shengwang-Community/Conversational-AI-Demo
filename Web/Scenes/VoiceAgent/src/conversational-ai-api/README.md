**Important Notes:**

> Users need to integrate and manage the initialization, lifecycle, and login status of RTC and RTM by themselves.
>
> Please ensure that the lifecycle of RTC and RTM instances is greater than the lifecycle of this component.
>
> Before using this component, please ensure that RTC is available and RTM is logged in.
>
> This component assumes that you have already integrated Agora RTC/RTM in your project, and the RTC SDK version should be **4.5.1 or above**.
>
> ⚠️ Before using this component, you must enable the "Real-time Messaging RTM" feature in the Agora Console, otherwise the component will not work properly.
>
> RTM Integration Guide: <TODO>

---

## Integration Steps

1. Copy the following files and folders to your Web project:

Web/Scenes/VoiceAgent/src/conversational-ai-api/index.ts

Web/Scenes/VoiceAgent/src/conversational-ai-api/type.ts

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/index.ts

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/events.ts

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/sub-render.ts

2. Ensure that your project has integrated Agora RTC/RTM, and the RTC version is **4.23.4 or above**.

---

## Quick Start

Please follow these steps to quickly integrate and use the ConversationalAI API:

1. **Initialize API Configuration**

   Create a configuration object using your RTC and RTM instances:

   ```typescript
   // init conversational AI API
   ConversationalAIAPI.init({
     rtcEngine,
     rtmEngine,
     // renderMode: ESubtitleHelperMode, if not specified, mode will be automatically determined based on messages, or manually specify mode
   });
   ```

2. **Get API Instance (Singleton)**

   ```typescript
   const conversationalAIAPI = ConversationalAIAPI.getInstance();
   ```

3. **Register Event Callbacks**

   Implement and add event callbacks to receive AI agent events and transcription content:

   ```typescript
   conversationalAIAPI.on(
     EConversationalAIAPIEvents.TRANSCRIPTION_UPDATED,
     onTextChanged
   );

   conversationalAIAPI.on(
     EConversationalAIAPIEvents.AGENT_STATE_CHANGED,
     onAgentStateChanged
   );

   conversationalAIAPI.on(
     EConversationalAIAPIEvents.AGENT_METRICS,
     onAgentMetricsChanged
   );

   conversationalAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, onAgentError);
   ```

4. **Subscribe to Channel Messages**

Call before starting the session:

```typescript
conversationalAIAPI.subscribeMessage(channel_name);
```

5. **(Required) Set Audio Parameters Before Joining RTC Channel**

Before passing the RTC client to the API component, you need to enable private parameters. Here's an example of enabling private parameters:

```typescript
AgoraRTC.setParameter("ENABLE_AUDIO_PTS_METADATA", true);

const client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
```

6. **(Optional) Interrupt Agent**

   ```typescript
   await conversationalAIAPI.interrupt(`${agent_rtc_uid}`);
   ```

7. **Destroy API Instance**

   ```typescript
   conversationalAIAPI.destroy();
   ```

---

## Notes

- **RTC Settings:**
  Before creating an RTC client each time, you must set private parameters to ensure PTS information can be received.

  ```typescript
  AgoraRTC.setParameter("ENABLE_AUDIO_PTS_METADATA", true);

  const client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
  ```

- **All TRANSCRIPTION_UPDATED event callbacks return the complete chat conversation list.**
  Each time may update the recent few conversation subtitles, please render the UI based on the complete list.

---

## File Structure

Web/Scenes/VoiceAgent/src/conversational-ai-api/index.ts - API class

Web/Scenes/VoiceAgent/src/conversational-ai-api/type.ts - API interfaces and related data structures and enums

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/index.ts - API utility functions

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/events.ts - Event management class, can extend this class to easily implement event listening and broadcasting

Web/Scenes/VoiceAgent/src/conversational-ai-api/utils/sub-render.ts - Subtitle module

> The above files and folders are all the content needed to integrate the ConversationalAI API, no need to copy other files.