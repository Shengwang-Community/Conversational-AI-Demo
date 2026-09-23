//
//  OnDeviceAins.swift
//  ConvoAI
//

enum OnDeviceAins {
    static func resolve(isDeveloperMode: Bool, debugEnabled: Bool) -> Bool {
        isDeveloperMode && debugEnabled
    }

    static func rtcParameter(enabled: Bool) -> String {
        "{\"che.audio.sf.enabled\":\(enabled)}"
    }
}

final class OnDeviceAinsController {
    private var isEnabled = false
    private let parameterWriter: (String) -> Void

    init(parameterWriter: @escaping (String) -> Void) {
        self.parameterWriter = parameterWriter
    }

    func loadAudioSettings(enabled: Bool, _ loadAudioSettings: () -> Void) {
        isEnabled = enabled
        loadAudioSettings()
        reapply()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        reapply()
    }

    func reapply() {
        parameterWriter(OnDeviceAins.rtcParameter(enabled: isEnabled))
    }

    func reset() {
        isEnabled = false
    }
}
