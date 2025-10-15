//
//  AgentSettingManager.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/12.
//

import Foundation
import Common

enum TranscriptDisplayMode: CaseIterable {
    //Transcript appear word by word, with subtitles and audio synchronized.
    case words
    //10 words every second
    case text
    //Transcript appear one by one.
    case chunk
    
    var renderMode: TranscriptRenderMode {
        if self == .words {
            return .words
        }
        
        return .text
    }
    
    var renderDisplayName: String {
        if self == .words {
            return ResourceManager.L10n.Settings.transcriptRenderWordMode
        }
        
        if self == .text {
            return ResourceManager.L10n.Settings.transcriptRenderPretextMode
        }
        
        if self == .chunk {
            return ResourceManager.L10n.Settings.transcriptRenderTextMode
        }
        
        return "" // Should not happen
    }

    var renderSubtitle: String {
        if self == .words {
            return ResourceManager.L10n.Settings.transcriptRenderWordModeDescription
        }
        
        if self == .text {
            return ResourceManager.L10n.Settings.transcriptRenderPretextModeDescription
        }
        
        if self == .chunk {
            return ResourceManager.L10n.Settings.transcriptRenderTextModeDescription
        }
        
        return ""
    }
}


class AgentPreference {
    var preset: AgentPreset?
    var language: SupportLanguage?
    var avatar: Avatar?
    var aiVad = false
    var bhvs = true
    var isCustomPreset = false
    var transcriptMode: TranscriptDisplayMode = .words
    var voiceprintMode: VoiceprintMode = .off
}

/// Agent setting change delegate protocol
protocol AgentSettingDelegate: AnyObject {
    func settingManager(_ manager: AgentSettingManager, presetDidUpdated preset: AgentPreset?)
    func settingManager(_ manager: AgentSettingManager, languageDidUpdated language: SupportLanguage?)
    func settingManager(_ manager: AgentSettingManager, avatarDidUpdated avatar: Avatar?)
    func settingManager(_ manager: AgentSettingManager, aiVadStateDidUpdated state: Bool)
    func settingManager(_ manager: AgentSettingManager, transcriptModeDidUpdated mode: TranscriptDisplayMode)
    func settingManager(_ manager: AgentSettingManager, voiceprintModeDidUpdated mode: VoiceprintMode)
    func settingManager(_ manager: AgentSettingManager, bhvsStateDidUpdated state: Bool)
}

/// Agent setting manager
/// Manages various agent configuration items such as presets, language, avatar, feature switches, etc.
class AgentSettingManager {
    // MARK: - Properties
   
    /// Configuration data model
    private var preference = AgentPreference()
     
    // MARK: - Delegate Management
    private var delegates = NSHashTable<AnyObject>.weakObjects()
     
    /// Add configuration change listener
    func addDelegate(_ delegate: AgentSettingDelegate) {
        delegates.add(delegate)
    }
     
    /// Remove configuration change listener
    func removeDelegate(_ delegate: AgentSettingDelegate) {
        delegates.remove(delegate)
    }
     
    // MARK: - Configuration Access
     
    /// Get read-only copy of current configuration
    var currentPreference: AgentPreference {
        return preference
    }
     
    /// Agent preset configuration
    var preset: AgentPreset? {
        get { preference.preset }
        set { updatePreset(newValue) }
    }
     
    /// Supported language
    var language: SupportLanguage? {
        get { preference.language }
        set { updateLanguage(newValue) }
    }
     
    /// Digital human avatar
    var avatar: Avatar? {
        get { preference.avatar }
        set { updateAvatar(newValue) }
    }
     
    /// AI interruption feature switch
    var aiVad: Bool {
        get { preference.aiVad }
        set { updateAiVadState(newValue) }
    }
     
    /// Voice lock feature switch
    var bhvs: Bool {
        get { preference.bhvs }
        set { updateBhvsState(newValue) }
    }
     
    /// Whether it is a custom preset
    var isCustomPreset: Bool {
        get { preference.isCustomPreset }
        set {
            preference.isCustomPreset = newValue
        }
    }
     
    /// Transcript display mode
    var transcriptMode: TranscriptDisplayMode {
        get { preference.transcriptMode }
        set { updateTranscriptMode(newValue) }
    }
     
    /// Voiceprint recognition mode
    var voiceprintMode: VoiceprintMode {
        get { preference.voiceprintMode }
        set { updateVoiceprintMode(newValue) }
    }
     
    // MARK: - Configuration Updates
     
    /// Update agent preset
    func updatePreset(_ preset: AgentPreset?) {
        if let preset = preset {
            // Update language based on preset
            let defaultLanguageCode = preset.defaultLanguageCode
            let supportLanguages = preset.supportLanguages
            
            var resetLanguageCode = defaultLanguageCode
            if defaultLanguageCode == nil, let languageCode = supportLanguages?.first?.languageCode {
                resetLanguageCode = languageCode
            }
            
            if let language = supportLanguages?.first(where: { $0.languageCode == resetLanguageCode }) {
                updateLanguage(language)
            } else {
                updateLanguage(nil)
            }
            
            // Reset avatar when changing preset
            updateAvatar(nil)
            
            // Update voiceprint mode based on preset
            if let enableSal = preset.enableSal {
                updateVoiceprintMode(enableSal ? .seamless : .off)
            } else {
                updateVoiceprintMode(.off)
            }
        } else {
            // If preset is nil, reset related settings
            updateLanguage(nil)
            updateAvatar(nil)
            updateVoiceprintMode(.off)
        }
        
        // Update preset and notify delegates
        preference.preset = preset
        notifyDelegates { $0.settingManager(self, presetDidUpdated: preset) }
    }
     
    /// Update language setting
    func updateLanguage(_ language: SupportLanguage?) {
        preference.language = language
        notifyDelegates { $0.settingManager(self, languageDidUpdated: language) }
    }
     
    /// Update digital human avatar information
    func updateAvatar(_ avatar: Avatar?) {
        preference.avatar = avatar
        notifyDelegates { $0.settingManager(self, avatarDidUpdated: avatar) }
    }
     
    /// Update AI interruption function state
    func updateAiVadState(_ state: Bool) {
        preference.aiVad = state
        notifyDelegates { $0.settingManager(self, aiVadStateDidUpdated: state) }
    }
     
    /// Update voice lock function state
    func updateBhvsState(_ state: Bool) {
        preference.bhvs = state
        notifyDelegates { $0.settingManager(self, bhvsStateDidUpdated: state) }
    }
     
    /// Update transcript display mode
    func updateTranscriptMode(_ mode: TranscriptDisplayMode) {
        preference.transcriptMode = mode
        notifyDelegates { $0.settingManager(self, transcriptModeDidUpdated: mode) }
    }
     
    /// Update voiceprint recognition mode
    func updateVoiceprintMode(_ mode: VoiceprintMode) {
        preference.voiceprintMode = mode
        notifyDelegates { $0.settingManager(self, voiceprintModeDidUpdated: mode) }
    }
     
    /// Reset all configurations to default values
    func resetToDefaults() {
        preference = AgentPreference()
    }
     
    // MARK: - Private Methods
     
    private func notifyDelegates(_ notification: (AgentSettingDelegate) -> Void) {
        for delegate in delegates.allObjects {
            if let delegate = delegate as? AgentSettingDelegate {
                notification(delegate)
            }
        }
    }
    
    
    private let kPresetAlertIgnoredKey = "preset_alert_ignored"
    
    func setPresetAlertIgnored(_ ignored: Bool) {
        UserDefaults.standard.set(ignored, forKey: kPresetAlertIgnoredKey)
    }
    
    func isPresetAlertIgnored() -> Bool {
        return UserDefaults.standard.bool(forKey: kPresetAlertIgnoredKey)
    }
}

// MARK: - AgentSettingDelegate Default Implementation
extension AgentSettingDelegate {
    func settingManager(_ manager: AgentSettingManager, presetDidUpdated preset: AgentPreset?) {}
    func settingManager(_ manager: AgentSettingManager, languageDidUpdated language: SupportLanguage?) {}
    func settingManager(_ manager: AgentSettingManager, avatarDidUpdated avatar: Avatar?) {}
    func settingManager(_ manager: AgentSettingManager, aiVadStateDidUpdated state: Bool) {}
    func settingManager(_ manager: AgentSettingManager, transcriptModeDidUpdated mode: TranscriptDisplayMode) {}
    func settingManager(_ manager: AgentSettingManager, voiceprintModeDidUpdated mode: VoiceprintMode) {}
    func settingManager(_ manager: AgentSettingManager, bhvsStateDidUpdated state: Bool) {}
}
