//
//  ChatViewController+TimeLimitted.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import SVProgressHUD
import Common

// MARK: - AgentTimerCoordinatorDelegate
extension ChatViewController: AgentTimerCoordinatorDelegate {
    func agentUseLimitedTimerClosed() {
        addLog("[Call] agentUseLimitedTimerClosed")
        topBar.stop()
    }
    
    func agentUseLimitedTimerStarted(duration: Int) {
        addLog("[Call] agentUseLimitedTimerStarted")
        topBar.showTips(seconds: duration)
        topBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerUpdated(duration: Int) {
        addLog("[Call] agentUseLimitedTimerUpdated")
        topBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerEnd() {
        addLog("[Call] agentUseLimitedTimerEnd")
        topBar.stop()
        stopLoading()
        stopAgent()
        let title = ResourceManager.L10n.ChannelInfo.timeLimitdAlertTitle
        if let manager = AppContext.preferenceManager(), let preset = manager.preference.preset {
            let min = preset.callTimeLimitSecond / 60
            TimeoutAlertView.show(in: view, image:UIImage.ag_named("ic_alert_timeout_icon"), title: title, description: String(format: ResourceManager.L10n.ChannelInfo.timeLimitdAlertDescription, min))
        }
    }
    
    func agentStartPing() {
        addLog("[Call] agentStartPing()")
        self.startPingRequest()
    }
    
    func agentNotJoinedWithinTheScheduledTime() {
        addLog("[Call] agentNotJoinedWithinTheScheduledTime")
        guard let manager = AppContext.preferenceManager() else {
            addLog("view controller or manager is release, will stop join channel scheduled timer")
            timerCoordinator.stopJoinChannelTimer()
            return
        }
        let avatarState = avatarIsSelected()
        var remoteIsJoined = self.agentIsJoined
        if avatarState {
            remoteIsJoined = agentIsJoined && avatarIsJoined
        }
        if remoteIsJoined {
            timerCoordinator.stopJoinChannelTimer()
            self.addLog("agent is joined in 10 seconds")
            return
        }
        
        if manager.information.agentState != .connected {
            addLog("agent is not joined in 10 seconds")
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Join.joinTimeoutTips)
            self.stopLoading()
            self.stopAgent()
        }
        
        timerCoordinator.stopJoinChannelTimer()
    }
}

extension ChatViewController {
    private func startPingRequest() {
        addLog("[Call] startPingRequest()")
        let presetName = AppContext.preferenceManager()?.preference.preset?.name ?? ""
        agentManager.ping(appId: AppContext.shared.appId, channelName: channelName, presetName: presetName) { [weak self] err, res in
            guard let self = self else { return }
            guard let error = err else {
                self.addLog("ping request")
                return
            }
            
            self.addLog("ping error : \(error.message)")
        }
    }
}
