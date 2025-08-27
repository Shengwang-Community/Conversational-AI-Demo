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
            public static let visionUnsupportMessage = ResourceManager.localizedString("conversation.vision.unsupport.message")
            public static let retryAfterConnect = ResourceManager.localizedString("conversation.vision.retry.after.connect")
            public static let voiceLockTips = ResourceManager.localizedString("conversation.agent.voice.lock.tips")
            public static let voiceprintLockToast = ResourceManager.localizedString("conversation.agent.voiceprint.lock.toast")
        }
        
        public enum Setting {
            public static let title = ResourceManager.localizedString("setting.title")
        }

        public enum Error {
            public static let networkError = ResourceManager.localizedString("error.network")
            public static let roomError = ResourceManager.localizedString("error.room.error")
            public static let joinError = ResourceManager.localizedString("error.join.error")
            public static let resouceLimit = ResourceManager.localizedString("error.join.error.resource.limit")
            public static let avatarLimit = ResourceManager.localizedString("error.join.error.avatar.limit")
            public static let networkDisconnected = ResourceManager.localizedString("error.network.disconnect")
            public static let microphonePermissionTitle = ResourceManager.localizedString("error.microphone.permission.alert.title")
            public static let microphonePermissionDescription = ResourceManager.localizedString("error.microphone.permission.alert.description")
            public static let permissionCancel = ResourceManager.localizedString("error.permission.alert.cancel")
            public static let permissionConfirm = ResourceManager.localizedString("error.permission.alert.confirm")
            public static let agentNotFound = ResourceManager.localizedString("error.agent.is.not.exist")
            public static let agentOffline = ResourceManager.localizedString("error.agent.is.offline")
            public static let agentListFetchFailed = ResourceManager.localizedString("error.agent.list.fetch.failed")
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
            public static let aiVadLight = ResourceManager.localizedString("settings.noise.aiVad.highlight")
            public static let transcriptRenderMode = ResourceManager.localizedString("settings.transcript.render.mode")
            public static let transcriptRenderWordMode = ResourceManager.localizedString("settings.transcript.render.word.mode")
            public static let transcriptRenderTextMode = ResourceManager.localizedString("settings.transcript.render.text.mode")
            public static let transcriptRenderPretextMode = ResourceManager.localizedString("settings.transcript.render.pretext.mode")
            public static let transcriptRenderWordModeDescription = ResourceManager.localizedString("settings.transcript.render.word.mode.description")
            public static let transcriptRenderTextModeDescription = ResourceManager.localizedString("settings.transcript.render.text.mode.description")
            public static let transcriptRenderPretextModeDescription = ResourceManager.localizedString("settings.transcript.render.pretext.mode.description")
            public static let bhvs = ResourceManager.localizedString("settings.noise.bhvs")
            public static let forceResponse = ResourceManager.localizedString("settings.noise.forceResponse")
            public static let agentConnected = ResourceManager.localizedString("settings.agent.connected")
            public static let agentDisconnected = ResourceManager.localizedString("settings.agent.disconnected")
            public static let digitalHuman = ResourceManager.localizedString("settings.digital.human")
            public static let digitalHumanClosed = ResourceManager.localizedString("settings.digital.human.closed")
            public static let digitalHumanPresetAlertTitle = ResourceManager.localizedString("settings.digital.human.preset.alert.title")
            public static let digitalHumanPresetAlertDescription = ResourceManager.localizedString("settings.digital.human.preset.alert.description")
            public static let digitalHumanLanguageAlertTitle = ResourceManager.localizedString("settings.digital.human.language.alert.title")
            public static let digitalHumanLanguageAlertDescription = ResourceManager.localizedString("settings.digital.human.language.alert.description")
            public static let digitalHumanAlertIgnore = ResourceManager.localizedString("settings.digital.human.alert.ignore")
            public static let digitalHumanAlertCancel = ResourceManager.localizedString("settings.digital.human.alert.cancel")
            public static let digitalHumanAlertConfirm = ResourceManager.localizedString("settings.digital.human.alert.confirm")
            public static let aiVadTips = ResourceManager.localizedString("settings.noise.aiVad.tips")
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
            public static let dump = ResourceManager.localizedString("devmode.dump")
            public static let sessionLimit = ResourceManager.localizedString("devmode.sessionLimit")
            public static let copyClick = ResourceManager.localizedString("devmode.copy.click")
            public static let close = ResourceManager.localizedString("devmode.close")
            public static let serverSwitch = ResourceManager.localizedString("devmode.server.switch")
            public static let sdkParams = ResourceManager.localizedString("devmode.sdk.params")
            public static let convoai = ResourceManager.localizedString("devmode.sc.config")
            public static let basicSettings = ResourceManager.localizedString("devmode.basic.settings")
            public static let convoaiSettings = ResourceManager.localizedString("devmode.convoai.settings")
            public static let userSettings = ResourceManager.localizedString("devmode.user.settings")
            public static let overallConfig = ResourceManager.localizedString("devmode.overall.config")
            public static let copyQuestion = ResourceManager.localizedString("devmode.copy.question")
            public static let captionMode = ResourceManager.localizedString("devmode.caption.mode")
            public static let userSettingsHint = ResourceManager.localizedString("devmode.user.settings.hint")
        }

        public enum Iot {
            public static let title = ResourceManager.localizedString("iot.info.title")
            public static let device = ResourceManager.localizedString("iot.info.device")
        }
        
        public enum Photo {
            public static let typePhoto = ResourceManager.localizedString("photo.type.photo")
            public static let typeCamera = ResourceManager.localizedString("photo.type.camera")
            public static let editDone = ResourceManager.localizedString("photo.edit.done")
            public static let formatTips = ResourceManager.localizedString("photo.format.tips")
            
            public static let permissionCancel = ResourceManager.localizedString("photo.permission.cancel")
            public static let permissionSettings = ResourceManager.localizedString("photo.permission.settings")
            public static let permissionSkip = ResourceManager.localizedString("photo.permission.skip")
            public static let permissionEnable = ResourceManager.localizedString("photo.permission.enable")
            
            public static let permissionPhotoTitle = ResourceManager.localizedString("photo.permission.photo.title")
            public static let permissionPhotoMessage = ResourceManager.localizedString("photo.permission.photo.message")
            
            public static let permissionPhotoPreviewTitle = ResourceManager.localizedString("photo.permission.photo.preview.title")
            public static let permissionPhotoPreviewMessage = ResourceManager.localizedString("photo.permission.photo.preview.message")
            
            public static let permissionCameraTitle = ResourceManager.localizedString("photo.permission.camera.title")
            public static let permissionCameraMessage = ResourceManager.localizedString("photo.permission.camera.message")
        }

        public enum AgentList {
            public static let contact = ResourceManager.localizedString("agent.list.contact")
            public static let input = ResourceManager.localizedString("agent.list.input")
            public static let custom = ResourceManager.localizedString("agent.list.custom")
            public static let official = ResourceManager.localizedString("agent.list.official")
            public static let fetch = ResourceManager.localizedString("agent.list.get")
            public static let getAgent = ResourceManager.localizedString("agent.list.get.agent")
            public static let agentSearchSuccess = ResourceManager.localizedString("agent.search.success")
        }
        
        public enum Empty {
            public static let loadingFailed = ResourceManager.localizedString("empty.state.loading.failed")
            public static let retry = ResourceManager.localizedString("empty.state.retry")
        }
        
        public enum VoiceprintMode {
            public static let title = ResourceManager.localizedString("settings.voiceprint.mode.title")
            public static let off = ResourceManager.localizedString("settings.voiceprint.mode.off")
            public static let offDescription = ResourceManager.localizedString("settings.voiceprint.mode.off.description")
            public static let seamless = ResourceManager.localizedString("settings.voiceprint.mode.seamless")
            public static let seamlessDescription = ResourceManager.localizedString("settings.voiceprint.mode.seamless.description")
            public static let aware = ResourceManager.localizedString("settings.voiceprint.mode.aware")
            public static let awareDescription = ResourceManager.localizedString("settings.voiceprint.mode.aware.description")
            public static let lockTitle = ResourceManager.localizedString("settings.voiceprint.lock.title")
            public static let settingSuccess = ResourceManager.localizedString("settings.voiceprint.setting.success")
            public static let recordingTitle = ResourceManager.localizedString("settings.voiceprint.recording.title")
            public static let recordingTime = ResourceManager.localizedString("settings.voiceprint.recording.time")
            public static let recordingInstruction = ResourceManager.localizedString("settings.voiceprint.recording.instruction")
            public static let recordingComplete = ResourceManager.localizedString("settings.voiceprint.recording.complete")
                    public static let pleaseRead = ResourceManager.localizedString("settings.voiceprint.please.read")
        public static let holdToRecord = ResourceManager.localizedString("settings.voiceprint.hold.to.record")
        public static let warning = ResourceManager.localizedString("settings.voiceprint.warning")
        public static let createTitle = ResourceManager.localizedString("settings.voiceprint.create.title")
        public static let createButton = ResourceManager.localizedString("settings.voiceprint.create.button")
        public static let reRecordButton = ResourceManager.localizedString("settings.voiceprint.re.record.button")
        public static let uploading = ResourceManager.localizedString("settings.voiceprint.uploading")
        public static let uploadFailed = ResourceManager.localizedString("settings.voiceprint.upload.failed")
        public static let dateFormat = ResourceManager.localizedString("settings.voiceprint.date.format")
        }
    }
}


