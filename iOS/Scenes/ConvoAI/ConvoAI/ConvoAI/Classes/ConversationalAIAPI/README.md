# ConversationalAI API

**Note**:

Users need to maintain the initialization, lifecycle, and login logic of RTC and RTM themselves, and need to ensure that the RTC and RTM instance lifecycles are longer than the component lifecycle. Before using the component, ensure that RTC is available and RTM is in a logged-in state.

## Usage Steps

1. Copy the ConversationalAIAPI folder and its files to your own project
2. Initialize the component
3. Add listeners
4. Subscribe to messages
5. Audio settings
6. Implement callbacks

## Code Implementation

### Basic Usage

#### 1. Declare Properties
In the UI module where you need to implement subtitles, declare the component as a member property:

```swift
private var convoAIAPI: ConversationalAIAPIImpl!
```

#### 2. Initialize Component

```swift
let config = ConversationalAIAPIConfig(
    rtcEngine: rtcEngine, 
    rtmEngine: rtmEngine, 
    renderMode: .words, 
    enableLog: true
)
self.convoAIAPI = ConversationalAIAPIImpl(config: config)
```

#### 3. Add Callback Listeners

```swift
convoAIAPI.addHandler(handler: self)
```

#### 4. Subscribe to Channel Messages
Subscribe to channel messages every time you start a call
**Note: Must be called after logging in to RTM**

```swift
convoAIAPI.subscribeMessage(channelName: channelName) { error in
    if let error = error {
        print("Subscription failed: \(error.message)")
    } else {
        print("Subscription successful")
    }
}
// ...
startAgent()
```

#### 5. Audio Settings
**Note: Call audio settings before joining the RTC channel each time:**

```swift
convoAIAPI.loadAudioSettings()

//..
rtcEngine.joinChannel(rtcToken: token, channelName: channelName, uid: uid, isIndependent: independent)

```

#### 6. Implement Callback Protocol
Implement the `ConversationalAIAPIEventHandler` callback protocol according to your needs.

For example, the subtitle protocol - the component will update subtitle information through this callback:

```swift
extension YourViewController: ConversationalAIAPIEventHandler {
    /// Real-time transcription update callback for displaying AI and user conversation content.
    func onTranscriptionUpdated(agentUserId: String, transcription: Transcription) {
        // Handle transcription updates
    }

    
    /// AI state change callback, including the following states:
    /// - `idle` - Idle state
    /// - `silent` - Silent state  
    /// - `listening` - Listening state
    /// - `thinking` - Thinking state
    /// - `speaking` - Speaking state
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // Handle state changes
    }

    //...
    //...
}
```

#### 7. Unsubscribe from Messages
Unsubscribe from messages every time you stop a call:

```swift
convoAIAPI.unsubscribeMessage(channelName: channelName) { error in
    if let error = error {
        print("Unsubscription failed: \(error.message)")
    } else {
        print("Unsubscription successful")
    }
}
// ...
stopAgent()
```

#### 8. Destroy Component
Destroy the component when exiting the current UI module:

```swift
convoAIAPI.destroy()
// ...
self.navigationController?.popViewController(animated: true)
```

### Advanced Features

#### Interrupt Function
You can actively interrupt the Agent by calling the component's `interrupt` function.

**Note**: The `agentUserId` here must be the agent's RTM userId and must be globally unique.

```swift
convoAIAPI.interrupt(agentUserId: "\(agentUid)") { error in
    if let error = error {
        print("Interrupt failed: \(error.message)")
    } else {
        print("Interrupt successful")
    }
}
```



