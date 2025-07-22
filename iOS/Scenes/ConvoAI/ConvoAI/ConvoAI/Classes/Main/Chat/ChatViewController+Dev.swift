//
//  ChatViewController+Dev.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import SVProgressHUD
import Common
import IoT

extension ChatViewController {
    @objc internal func onClickDevMode() {
        DeveloperConfig.shared
            .setServerHost(AppContext.preferenceManager()?.information.targetServer ?? "")
            .setAudioDump(enabled: rtcManager.getAudioDump(), onChange: { [weak self] isOn in
                self?.rtcManager.enableAudioDump(enabled: isOn)
            })
            .setSessionLimit(enabled: !DeveloperConfig.shared.getSessionFree(), onChange: { [weak self] isOn in
                self?.timerCoordinator.setDurationLimit(limited: isOn)
            })
            .setMetrics(enabled: DeveloperConfig.shared.metrics, onChange: { [weak self] isOn in
                self?.enableMetric = isOn
            })
            .setCloseDevModeCallback { [weak self] in
                self?.devModeButton.isHidden = true
                self?.sendMessageButton.isHidden = true
            }
            .setSwitchServerCallback { [weak self] in
                self?.switchEnvironment()
            }
            .setSDKParamsCallback { [weak self] param in
                self?.rtcManager.getRtcEntine().setParameters(param)
            }
            .setCopyCallback { [weak self] in
                let messageContents = self?.messageView.getAllMessages()
                    .filter { $0.isMine }
                    .map { $0.content }
                    .joined(separator: "\n")
                let pasteboard = UIPasteboard.general
                pasteboard.string = messageContents
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.DevMode.copy)
            }
        DeveloperModeViewController.show(from: self)
    }
    
    private func switchEnvironment() {
        deleteAllPresets()
        stopLoading()
        stopAgent()
        animateView.releaseView()
        rtcManager.destroy()
        rtmManager.destroy()
        UserCenter.shared.logout()
        NotificationCenter.default.post(name: .EnvironmentChanged, object: nil, userInfo: nil)
    }
    
    internal func deleteAllPresets() {
        IoTEntrance.deleteAllPresets()
        AppContext.preferenceManager()?.deleteAllPresets()
    }
}
