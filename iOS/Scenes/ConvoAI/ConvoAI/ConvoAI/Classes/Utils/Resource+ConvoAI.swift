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
            
            public static let chat = ResourceManager.localizedString("main.chat")
            public static let agents = ResourceManager.localizedString("main.agents")
            public static let digitalHuman = ResourceManager.localizedString("main.digitalHuman")
            public static let mine = ResourceManager.localizedString("main.mine")
        }

        public enum Scene {
            public static let aiCardDes = ResourceManager.localizedString("scene.ai.card.des")
            public static let v2vCardTitle = ResourceManager.localizedString("scene.v2v.card.title")
            public static let v2vCardDes = ResourceManager.localizedString("scene.v2v.card.des")
        }

        public enum Login {
            public static let title = ResourceManager.localizedString("login.title")
            public static let signup = ResourceManager.localizedString("login.start.button.signup")
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

            public static let termsAlertTitle = ResourceManager.localizedString("login.terms.alert.title")
            public static let termsAlertContent = ResourceManager.localizedString("login.terms.alert.content")
            public static let termsAlertDeclineButton = ResourceManager.localizedString("login.terms.alert.decline.button")
            public static let termsAlertAcceptButton = ResourceManager.localizedString("login.terms.alert.accept.button")
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
            public static let digitalHumanAll = ResourceManager.localizedString("settings.digital.human.all")
            public static let digitalHumanPresetAlertTitle = ResourceManager.localizedString("settings.digital.human.preset.alert.title")
            public static let digitalHumanPresetAlertDescription = ResourceManager.localizedString("settings.digital.human.preset.alert.description")
            public static let digitalHumanLanguageAlertTitle = ResourceManager.localizedString("settings.digital.human.language.alert.title")
            public static let digitalHumanLanguageAlertDescription = ResourceManager.localizedString("settings.digital.human.language.alert.description")
            public static let digitalHumanAlertIgnore = ResourceManager.localizedString("settings.digital.human.alert.ignore")
            public static let digitalHumanAlertCancel = ResourceManager.localizedString("settings.digital.human.alert.cancel")
            public static let digitalHumanAlertConfirm = ResourceManager.localizedString("settings.digital.human.alert.confirm")
            public static let aiVadTips = ResourceManager.localizedString("settings.noise.aiVad.tips")
            public static let aiGeneratedContent = ResourceManager.localizedString("avatar.ai.generated.content")
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
            public static let serverStatusTitle = ResourceManager.localizedString("channel.serverStatus.title")
            public static let voiceprintLock = ResourceManager.localizedString("channel.voiceprint.lock")
            public static let elegantInterrupt = ResourceManager.localizedString("channel.elegant.interrupt")
            public static let more = ResourceManager.localizedString("channel.more")
            public static let seamless = ResourceManager.localizedString("channel.seamless")
            public static let aware = ResourceManager.localizedString("channel.aware")
            public static let effective = ResourceManager.localizedString("channel.effective")
            public static let notEffective = ResourceManager.localizedString("channel.not.effective")
            public static let insensitive = ResourceManager.localizedString("channel.insensitive")
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
            public static let title = ResourceManager.localizedString("agentlist.title")
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
        
        public enum Voiceprint {
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
            public static let uploadSuccess = ResourceManager.localizedString("settings.voiceprint.upload.success")
            public static let dateFormat = ResourceManager.localizedString("settings.voiceprint.date.format")
            public static let recordingTooShort = ResourceManager.localizedString("settings.voiceprint.recording.too.short")
            public static let tipText = ResourceManager.localizedString("settings.voiceprint.tip.text")
            public static let alertTitle = ResourceManager.localizedString("settings.voiceprint.alert.title")
            public static let alertContent = ResourceManager.localizedString("settings.voiceprint.alert.content")
            public static let alertSeamlessContent = ResourceManager.localizedString("settings.voiceprint.alert.seamless.content")
            public static let alertCancel = ResourceManager.localizedString("settings.voiceprint.alert.cancel")
            public static let alertConfirm = ResourceManager.localizedString("settings.voiceprint.alert.confirm")
            public static let alertNoVoiceprintTitle = ResourceManager.localizedString("settings.voiceprint.alert.no.voiceprint.title")
            public static let alertNoVoiceprintContent = ResourceManager.localizedString("settings.voiceprint.alert.no.voiceprint.content")
            public static let alertExit = ResourceManager.localizedString("settings.voiceprint.alert.exit")
            public static let recordingText = ResourceManager.localizedString("settings.voiceprint.recording.text")
        }
        
        public enum Mine {
            // Page Title
            public static let pageTitle = ResourceManager.localizedString("mine.page.title")
            
            // Mine Module UI
            public static let personaTitle = ResourceManager.localizedString("mine.persona.title")
            public static let addressingTitle = ResourceManager.localizedString("mine.addressing.title")
            public static let birthdayTitle = ResourceManager.localizedString("mine.birthday.title")
            public static let bioTitle = ResourceManager.localizedString("mine.bio.title")
            public static let iotDevicesTitle = ResourceManager.localizedString("mine.iot.devices.title")
            public static let iotDevicesCount = ResourceManager.localizedString("mine.iot.devices.count")
            public static let iotDevicesClickToBind = ResourceManager.localizedString("mine.iot.devices.click.to.bind")
            public static let settingsTitle = ResourceManager.localizedString("mine.settings.title")
            
            // Nickname Setting
            public static let nicknameTitle = ResourceManager.localizedString("mine.nickname.title")
            public static let nicknamePlaceholder = ResourceManager.localizedString("mine.nickname.placeholder")
            public static let nicknameUpdateSuccess = ResourceManager.localizedString("mine.nickname.update.success")
            public static let nicknameUpdateFailed = ResourceManager.localizedString("mine.nickname.update.failed")
            public static let nicknameInvalidCharacters = ResourceManager.localizedString("mine.nickname.invalid.characters")
            
            // Gender Setting
            public static let genderTitle = ResourceManager.localizedString("mine.gender.title")
            public static let genderFemale = ResourceManager.localizedString("mine.gender.female")
            public static let genderMale = ResourceManager.localizedString("mine.gender.male")
            public static let genderConfirm = ResourceManager.localizedString("mine.gender.confirm")
            
            // Birthday Setting
            public static let birthdaySelectTitle = ResourceManager.localizedString("mine.birthday.select.title")
            public static let birthdayCancel = ResourceManager.localizedString("mine.birthday.cancel")
            public static let birthdayConfirm = ResourceManager.localizedString("mine.birthday.confirm")
            
            // Bio Setting
            public static let bioSettingTitle = ResourceManager.localizedString("mine.bio.setting.title")
            public static let bioPlaceholderDisplay = ResourceManager.localizedString("mine.bio.placeholder.display")
            public static let bioInputPlaceholder = ResourceManager.localizedString("mine.bio.input.placeholder")
            public static let placeholderSelect = ResourceManager.localizedString("mine.placeholder.select")
            public static let bioExample1 = ResourceManager.localizedString("mine.bio.example.1")
            public static let bioExample2 = ResourceManager.localizedString("mine.bio.example.2")
            public static let bioExample3 = ResourceManager.localizedString("mine.bio.example.3")
            public static let bioExample4 = ResourceManager.localizedString("mine.bio.example.4")
            
            // Privacy Settings
            public static let privacyTitle = ResourceManager.localizedString("mine.privacy.title")
            public static let privacyUserAgreement = ResourceManager.localizedString("mine.privacy.userAgreement")
            public static let privacyPrivacyPolicy = ResourceManager.localizedString("mine.privacy.privacyPolicy")
            public static let privacyDataSharing = ResourceManager.localizedString("mine.privacy.dataSharing")
            public static let privacyPersonalInfo = ResourceManager.localizedString("mine.privacy.personalInfo")
            public static let privacyRecordNumber = ResourceManager.localizedString("mine.privacy.recordNumber")
            
            // Account Settings
            public static let accountDeactivateWarningMessage = ResourceManager.localizedString("mine.account.deactivateWarning.message")
            public static let accountDeactivateAccount = ResourceManager.localizedString("mine.account.deactivateAccount")
            public static let accountLogout = ResourceManager.localizedString("mine.account.logout")
            public static let accountImportantNotice = ResourceManager.localizedString("mine.account.importantNotice")
            public static let accountDeactivateMessage = ResourceManager.localizedString("mine.account.deactivateMessage")
            public static let accountUnderstandRisks = ResourceManager.localizedString("mine.account.understandRisks")
            public static let accountCancel = ResourceManager.localizedString("mine.account.cancel")
            public static let accountConfirmDeactivate = ResourceManager.localizedString("mine.account.confirmDeactivate")
            
            // Nickname Generation
            public static let nicknameAdjectives = ResourceManager.localizedString("mine.nickname.adjectives")
            public static let nicknameNouns = ResourceManager.localizedString("mine.nickname.nouns")
            public static let icpSubtitle = ResourceManager.localizedString("mine.icp.subtitle")
        }
        
        public enum Sip {
            public static let sipCallInTips = ResourceManager.localizedString("agent.sip.in.call.tips")
            public static let sipCallOutTips = ResourceManager.localizedString("agent.sip.out.call.tips")
            public static let sipCallingTips = ResourceManager.localizedString("agent.sip.calling.tips")
            public static let sipInputPlaceholder = ResourceManager.localizedString("agent.sip.input.placeholder")
            public static let sipOnCallTips = ResourceManager.localizedString("agent.sip.on.call.tips")
            public static let sipEndCallTips = ResourceManager.localizedString("agent.sip.end.call.tips")
            public static let sipPhoneInvalid = ResourceManager.localizedString("agent.sip.phone.invalid")
            public static let callout = ResourceManager.localizedString("agent.sip.callout")
            public static let callAlertTitle = ResourceManager.localizedString("agent.sip.call.alert.title")
            public static let callAlertMessage = ResourceManager.localizedString("agent.sip.call.alert.message")
            public static let callAlertCancel = ResourceManager.localizedString("agent.sip.call.alert.cancel")
            public static let callAlertConfirm = ResourceManager.localizedString("agent.sip.call.alert.confirm")
            public static let areaCodeSearchPlaceholder = ResourceManager.localizedString("agent.sip.area.code.search.placeholder")
            public static let areaCodeSearchButton = ResourceManager.localizedString("agent.sip.area.code.search.button")
            public static let areaCodeNoResults = ResourceManager.localizedString("agent.sip.area.code.no.results")
            public static let callLimitExceeded = ResourceManager.localizedString("agent.sip.call.limit.exceeded")
        }
    }
}
