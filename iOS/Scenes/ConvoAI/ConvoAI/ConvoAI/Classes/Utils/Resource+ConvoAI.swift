//
//  Resource+VoiceAgent.swift
//  DigitalHuman
//
//  Created by qinhui on 2025/1/16.
//

import Foundation
import Common

extension ResourceManager {
    static func localizedString(_ key: String) -> String {
        return localizedString(key, bundleName: ConvoAIEntrance.kSceneName)
    }
    
    enum L10n {
        public enum Main {
            public static let getStart = ResourceManager.localizedString("main.get.start")
            public static let agreeTo = ResourceManager.localizedString("main.agree.to")
            public static let termsOfService = ResourceManager.localizedString("main.terms.vc.title")
            public static let termsService = ResourceManager.localizedString("main.terms.service")
        }

        public enum Scene {
            public static let aiCardDes = ResourceManager.localizedString("scene.ai.card.des")
            public static let v2vCardTitle = ResourceManager.localizedString("scene.v2v.card.title")
            public static let v2vCardDes = ResourceManager.localizedString("scene.v2v.card.des")
            public static let digCardTitle = ResourceManager.localizedString("scene.dig.card.title")
            public static let digCardDes = ResourceManager.localizedString("scene.dig.card.des")
        }

        public enum Login {
            public static let title = ResourceManager.localizedString("login.title")
            public static let description = ResourceManager.localizedString("login.description")
            public static let buttonTitle = ResourceManager.localizedString("login.start.button.title")
            public static let termsServicePrefix = ResourceManager.localizedString("login.terms.service.prefix")
            public static let termsServiceName = ResourceManager.localizedString("login.terms.service.name")
            public static let termsServiceAndWord = ResourceManager.localizedString("login.terms.service.and")
            public static let termsPrivacyName = ResourceManager.localizedString("login.privacy.policy.name")
            public static let termsServiceTips = ResourceManager.localizedString("login.terms.service.tips")
            public static let sessionExpired = ResourceManager.localizedString("login.session.expired")
            
            public static let logoutAlertTitle = ResourceManager.localizedString("logout.alert.title")
            public static let logoutAlertDescription = ResourceManager.localizedString("logout.alert.description")
            public static let logoutAlertConfirm = ResourceManager.localizedString("logout.alert.cancel.title")
            public static let logoutAlertCancel = ResourceManager.localizedString("logout.alert.confirm.title")

        }

        public enum Join {
            public static let title = ResourceManager.localizedString("join.start.title")
            public static let state = ResourceManager.localizedString("join.start.state")
            public static let tips = ResourceManager.localizedString("join.start.tips")
            public static let tipsNoLimit = ResourceManager.localizedString("join.start.tips.no.limit")
            public static let buttonTitle = ResourceManager.localizedString("join.start.button.title")
            public static let agentName = ResourceManager.localizedString("join.start.agent.name")
            public static let agentConnecting = ResourceManager.localizedString("conversation.agent.connecting")
            public static let joinTimeoutTips = ResourceManager.localizedString("join.timeout.tips")
        }

        public enum Conversation {
            public static let appHello = ResourceManager.localizedString("conversation.ai.hello")
            public static let appWelcomeTitle = ResourceManager.localizedString("conversation.ai.welcome.title")
            public static let appWelcomeDescription = ResourceManager.localizedString("conversation.ai.welcome.description")
            public static let appName = ResourceManager.localizedString("conversation.ai.app.name")
            public static let agentName = ResourceManager.localizedString("conversation.agent.name")
            public static let buttonEndCall = ResourceManager.localizedString("conversation.button.end.call")
            public static let agentLoading = ResourceManager.localizedString("conversation.agent.loading")
            public static let agentJoined = ResourceManager.localizedString("conversation.agent.joined")
            public static let joinFailed = ResourceManager.localizedString("conversation.join.failed")
            public static let agentLeave = ResourceManager.localizedString("conversation.agent.leave")
            public static let endCallLoading = ResourceManager.localizedString("conversation.end.call.loading")
            public static let endCallLeave = ResourceManager.localizedString("conversation.end.call.leave")
            public static let messageYou = ResourceManager.localizedString("conversation.message.you")
            public static let messageAgentName = ResourceManager.localizedString("conversation.message.agent.name")
            public static let clearMessageTitle = ResourceManager.localizedString("conversation.message.alert.title")
            public static let clearMessageContent = ResourceManager.localizedString("conversation.message.alert.content")
            public static let alertCancel = ResourceManager.localizedString("conversation.alert.cancel")
            public static let alertClear = ResourceManager.localizedString("conversation.alert.clear")
            public static let userSpeakToast = ResourceManager.localizedString("conversation.user.speak.toast")
            public static let agentInterrputed = ResourceManager.localizedString("conversation.agent.interrputed")
            public static let agentStateSilent = ResourceManager.localizedString("conversation.agent.state.silent")
            public static let agentStateListening = ResourceManager.localizedString("conversation.agent.state.listening")
            public static let agentStateSpeaking = ResourceManager.localizedString("conversation.agent.state.speaking")
            public static let agentStateMuted = ResourceManager.localizedString("conversation.agent.state.muted")
            public static let agentTranscription = ResourceManager.localizedString("conversation.agent.transcription")
        }
        
        public enum Setting {
            public static let title = ResourceManager.localizedString("setting.title")
        }

        public enum Error {
            public static let networkError = ResourceManager.localizedString("error.network")
            public static let roomError = ResourceManager.localizedString("error.room.error")
            public static let joinError = ResourceManager.localizedString("error.join.error")
            public static let resouceLimit = ResourceManager.localizedString("error.join.error.resource.limit")
            public static let networkDisconnected = ResourceManager.localizedString("error.network.disconnect")
            public static let microphonePermissionTitle = ResourceManager.localizedString("error.microphone.permission.alert.title")
            public static let microphonePermissionDescription = ResourceManager.localizedString("error.microphone.permission.alert.description")
            public static let permissionCancel = ResourceManager.localizedString("error.permission.alert.cancel")
            public static let permissionConfirm = ResourceManager.localizedString("error.permission.alert.confirm")
        }

        public enum Settings {
            public static let title = ResourceManager.localizedString("settings.title")
            public static let tips = ResourceManager.localizedString("settings.connected.tips")
            public static let preset = ResourceManager.localizedString("settings.preset")
            public static let advanced = ResourceManager.localizedString("settings.advanced")
            public static let device = ResourceManager.localizedString("settings.device")
            public static let language = ResourceManager.localizedString("settings.language")
            public static let voice = ResourceManager.localizedString("settings.voice")
            public static let model = ResourceManager.localizedString("settings.model")
            public static let microphone = ResourceManager.localizedString("settings.microphone")
            public static let speaker = ResourceManager.localizedString("settings.speaker")
            public static let noiseCancellation = ResourceManager.localizedString("settings.noise.cancellation")
            public static let aiVadNormal = ResourceManager.localizedString("settings.noise.aiVad.nomal")
            public static let aiVadLight = ResourceManager.localizedString("settings.noise.aiVad.highlight")
            public static let bhvs = ResourceManager.localizedString("settings.noise.bhvs")
            public static let forceResponse = ResourceManager.localizedString("settings.noise.forceResponse")
            public static let agentConnected = ResourceManager.localizedString("settings.agent.connected")
            public static let agentDisconnected = ResourceManager.localizedString("settings.agent.disconnected")
            public static let digitalHuman = ResourceManager.localizedString("settings.digital.human")
            public static let digitalHumanClosed = ResourceManager.localizedString("settings.digital.human.closed")
            public static let digitalHumanAlertTitle = ResourceManager.localizedString("settings.digital.human.alert.title")
            public static let digitalHumanAlertDescription = ResourceManager.localizedString("settings.digital.human.alert.description")
            public static let digitalHumanAlertIgnore = ResourceManager.localizedString("settings.digital.human.alert.ignore")
            public static let digitalHumanAlertCancel = ResourceManager.localizedString("settings.digital.human.alert.cancel")
            public static let digitalHumanAlertConfirm = ResourceManager.localizedString("settings.digital.human.alert.confirm")
        }
        
        public enum ChannelInfo {
            public static let deviceTitle = ResourceManager.localizedString("channel.info.device.titie")
            public static let title = ResourceManager.localizedString("channel.info.title")
            public static let subtitle = ResourceManager.localizedString("channel.info.subtitle")
            public static let networkInfoTitle = ResourceManager.localizedString("channel.network.info.title")
            public static let agentStatus = ResourceManager.localizedString("channel.info.agent.status")
            public static let agentId = ResourceManager.localizedString("channel.info.agent.id")
            public static let roomStatus = ResourceManager.localizedString("channel.info.room.status")
            public static let roomId = ResourceManager.localizedString("channel.info.room.id")
            public static let yourId = ResourceManager.localizedString("channel.info.your.id")
            public static let yourNetwork = ResourceManager.localizedString("channel.info.your.network")
            public static let connectedState = ResourceManager.localizedString("channel.connected.state")
            public static let disconnectedState = ResourceManager.localizedString("channel.disconnected.state")
            public static let copyToast = ResourceManager.localizedString("channel.info.copied")
            public static let networkGood = ResourceManager.localizedString("channel.network.good")
            public static let networkPoor = ResourceManager.localizedString("channel.network.poor")
            public static let networkFair = ResourceManager.localizedString("channel.network.fair")
            public static let moreInfo = ResourceManager.localizedString("channel.more.title")
            public static let feedback = ResourceManager.localizedString("channel.more.feedback")
            public static let feedbackLoading = ResourceManager.localizedString("channel.more.feedback.uploading")
            public static let feedbackSuccess = ResourceManager.localizedString("channel.more.feedback.success")
            public static let feedbackFailed = ResourceManager.localizedString("channel.more.feedback.failed")
            public static let logout = ResourceManager.localizedString("channel.more.logout")
            public static let timeLimitdAlertTitle = ResourceManager.localizedString("channel.time.limited.alert.title")
            public static let timeLimitdAlertDescription = ResourceManager.localizedString("channel.time.limited.alert.description")
            public static let timeLimitdAlertConfim = ResourceManager.localizedString("channel.time.limited.alert.confim")
        }
        
        public enum DevMode {
            public static let title = ResourceManager.localizedString("devmode.title")
            public static let graph = ResourceManager.localizedString("devmode.graph")
            public static let rtc = ResourceManager.localizedString("devmode.rtc")
            public static let rtm = ResourceManager.localizedString("devmode.rtm")
            public static let metrics = ResourceManager.localizedString("devmode.metric")
            public static let host = ResourceManager.localizedString("devmode.host")
            public static let dump = ResourceManager.localizedString("devmode.dump")
            public static let sessionLimit = ResourceManager.localizedString("devmode.sessionLimit")
            public static let copy = ResourceManager.localizedString("devmode.copy")
            public static let close = ResourceManager.localizedString("devmode.close")
            public static let server = ResourceManager.localizedString("devmode.server")
            public static let sdkParams = ResourceManager.localizedString("devmode.sdk.params")
            public static let convoai = ResourceManager.localizedString("devmode.sc.config")
            public static let textView = ResourceManager.localizedString("devmode.text.view")
            public static let textConfirm = ResourceManager.localizedString("devmode.text.confirm")
        }

        public enum Iot {
            public static let title = ResourceManager.localizedString("iot.info.title")
            public static let device = ResourceManager.localizedString("iot.info.device")
        }
    }
}


