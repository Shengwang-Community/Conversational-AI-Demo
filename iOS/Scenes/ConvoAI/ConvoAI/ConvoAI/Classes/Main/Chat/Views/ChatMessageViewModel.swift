//
//  ChatMessageViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/19.
//

import Foundation
import Common

enum ImageState {
    case sending, success, failed
}

enum MessageLatencyMetricKind: Equatable {
    case turn
    case e2e
    case rtc
    case algorithm
    case asr
    case llm
    case tts
}

struct MessageLatencyMetricEntry: Equatable {
    let kind: MessageLatencyMetricKind
    let value: Int
    let isMilliseconds: Bool
}

struct MessageLatencyInfo: Equatable {
    let turnId: Int
    let e2eLatency: Int
    let rtcLatency: Int?
    let algorithmLatency: Int?
    let asrLatency: Int?
    let llmLatency: Int?
    let ttsLatency: Int?

    init(turn: Turn) {
        turnId = turn.turnId
        e2eLatency = Self.normalizedRequired(turn.e2eLatency)
        rtcLatency = Self.normalizedOptional(turn.segmentedLatency.transport)
        algorithmLatency = Self.normalizedOptional(turn.segmentedLatency.algorithmProcessing)
        asrLatency = Self.normalizedOptional(turn.segmentedLatency.asrTTLW)
        llmLatency = Self.normalizedOptional(turn.segmentedLatency.llmTTFT)
        ttsLatency = Self.normalizedOptional(turn.segmentedLatency.ttsTTFB)
    }

    var orderedEntries: [MessageLatencyMetricEntry] {
        var entries: [MessageLatencyMetricEntry] = [
            MessageLatencyMetricEntry(kind: .turn, value: turnId, isMilliseconds: false),
            MessageLatencyMetricEntry(kind: .e2e, value: e2eLatency, isMilliseconds: true),
        ]

        [
            (MessageLatencyMetricKind.rtc, rtcLatency),
            (.algorithm, algorithmLatency),
            (.asr, asrLatency),
            (.llm, llmLatency),
            (.tts, ttsLatency),
        ].forEach { kind, value in
            guard let value else { return }
            entries.append(MessageLatencyMetricEntry(kind: kind, value: value, isMilliseconds: true))
        }

        return entries
    }

    private static func normalizedRequired(_ value: Double) -> Int {
        max(Int(value.rounded()), 0)
    }

    private static func normalizedOptional(_ value: Double) -> Int? {
        let normalized = Int(value.rounded())
        return normalized > 0 ? normalized : nil
    }
}

class ImageSource {
    var imageData: UIImage? = nil
    var imageUUID: String = ""
    var imageState: ImageState = .sending
}

class Message {
    var content: String = ""
    var imageSource: ImageSource? = nil
    var isMine: Bool = false
    var isFinal: Bool = false
    var isInterrupted: Bool = false
    var timestamp: Int64 = 0
    var turn_id: Int = -100
    var local_turn: Int = 0
    var index: Int = 0
    var transcript: String = ""
    var latencyInfo: MessageLatencyInfo?
    var isImage: Bool {
        return imageSource != nil
    }

    var snapshotText: String {
        if isMine {
            return content.isEmpty ? transcript : content
        }
        return transcript.isEmpty ? content : transcript
    }

    var shouldShowLatencyMetrics: Bool {
        !isMine && latencyInfo != nil && AppContext.settingManager().latencyMetricsVisible
    }
}

protocol ChatMessageViewModelDelegate: AnyObject {
    func messageUpdated()
    func messageFinished()
}

class ChatMessageViewModel: NSObject {
    var messages: [Message] = []
    var messageMapTable: [String : Message] = [:]
    var pendingLatencyInfoTable: [Int: MessageLatencyInfo] = [:]
    var lastMessage: Message?
    weak var delegate: ChatMessageViewModelDelegate?
    var timer: Timer?
    var displayMode: TranscriptDisplayMode = .words
    var realRenderMode: TranscriptRenderMode = .text

    override init() {
        super.init()
        registerDelegate()
        displayMode = AppContext.settingManager().transcriptMode
    }
    
    func clearMessage() {
        messages.removeAll()
        messageMapTable.removeAll()
        pendingLatencyInfoTable.removeAll()
        stopTimer()
    }
    
    func registerDelegate() {
        AppContext.settingManager().addDelegate(self)
    }
}

extension ChatMessageViewModel: AgentSettingDelegate {
    func settingManager(_ manager: AgentSettingManager, latencyMetricsVisibilityDidUpdated state: Bool) {
        delegate?.messageUpdated()
    }

    func settingManager(_ manager: AgentSettingManager, transcriptModeDidUpdated mode: TranscriptDisplayMode) {
        displayMode = mode
    }
}
