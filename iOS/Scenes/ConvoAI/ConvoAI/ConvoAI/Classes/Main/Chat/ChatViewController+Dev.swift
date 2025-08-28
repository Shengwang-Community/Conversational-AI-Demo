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

extension ChatViewController: DeveloperConfigDelegate {
    internal func configDevMode() {
        navivationBar.characterButton.addTarget(self, action: #selector(onClickLogo), for: .touchUpInside)

        DeveloperConfig.shared.add(delegate: self)
        
        if (DeveloperConfig.shared.isDeveloperMode) {
            self.sendMessageButton.isHidden = false
            applyDevParams()
        } else {
            self.sendMessageButton.isHidden = true
        }
    }
    
    public func applyDevParams() {
        self.enableMetric = DeveloperConfig.shared.metrics
        self.timerCoordinator.setDurationLimit(limited: DeveloperConfig.shared.getSessionLimit())
        self.rtcManager.enableAudioDump(enabled: DeveloperConfig.shared.audioDump)
        DeveloperConfig.shared.sdkParams.forEach { p in
            self.rtcManager.getRtcEntine().setParameters(p)
        }
    }
    
    public func devConfigDidOpenDevMode(_ config: DeveloperConfig) {
        self.sendMessageButton.isHidden = false
        applyDevParams()
    }
    
    public func devConfigDidCloseDevMode(_ config: DeveloperConfig) {
        self.sendMessageButton.isHidden = true
    }
    
    public func devConfigDidSwitchServer(_ config: DeveloperConfig) {
        stopLoading()
        stopAgent()
        animateView.releaseView()
        rtcManager.destroy()
        rtmManager.destroy()
    }
    
    public func devConfigDidCopy(_ config: DeveloperConfig) {
        let messageContents = self.messageView.getAllMessages()
            .filter { $0.isMine }
            .map { $0.content }
            .joined(separator: "\n")
        let pasteboard = UIPasteboard.general
        pasteboard.string = messageContents
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.DevMode.copyQuestion)
    }

    public func devConfig(_ config: DeveloperConfig, sessionLimitDidChange enabled: Bool) {
        self.timerCoordinator.setDurationLimit(limited: enabled)
    }

    public func devConfig(_ config: DeveloperConfig, audioDumpDidChange enabled: Bool) {
        self.rtcManager.enableAudioDump(enabled: enabled)
    }

    public func devConfig(_ config: DeveloperConfig, metricsDidChange enabled: Bool) {
        self.enableMetric = enabled
    }

    public func devConfig(_ config: DeveloperConfig, sdkParamsDidChange params: String) {
        self.rtcManager.getRtcEntine().setParameters(params)
    }
    
    @objc func onClickLogo() {
        DeveloperConfig.shared.countTouch()
    }
}
