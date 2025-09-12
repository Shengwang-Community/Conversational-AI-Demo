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
        sideNavigationBar.stop()
    }
    
    func agentUseLimitedTimerStarted(duration: Int) {
        addLog("[Call] agentUseLimitedTimerStarted")
        sideNavigationBar.showTips(seconds: duration)
        sideNavigationBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerUpdated(duration: Int) {
        addLog("[Call] agentUseLimitedTimerUpdated")
        sideNavigationBar.updateRestTime(duration)
    }
    
    func agentUseLimitedTimerEnd() {
        addLog("[Call] agentUseLimitedTimerEnd")
        sideNavigationBar.stop()
        stopLoading()
        stopAgent()
        let title = ResourceManager.L10n.ChannelInfo.timeLimitdAlertTitle
        if let preset = AppContext.settingManager().preset, let callTimeLimitSecond = preset.callTimeLimitSecond {
            var min = callTimeLimitSecond / 60
            
            if let _ = AppContext.settingManager().avatar {
                min = preset.callTimeLimitAvatarSecond ?? 600 / 60
            }

            TimeoutAlertView.show(in: view, image:UIImage.ag_named("ic_alert_timeout_icon"), title: title, description: String(format: ResourceManager.L10n.ChannelInfo.timeLimitdAlertDescription, min))
        }
    }
    
    func agentStartPing() {
        addLog("[Call] agentStartPing()")
        self.startPingRequest()
    }
    
    func agentNotJoinedWithinTheScheduledTime() {
        addLog("[Call] agentNotJoinedWithinTheScheduledTime")
        let avatarState = isEnableAvatar()
        var remoteIsJoined = self.agentIsJoined
        if avatarState {
            remoteIsJoined = agentIsJoined && avatarIsJoined
        }
        if remoteIsJoined {
            timerCoordinator.stopJoinChannelTimer()
            self.addLog("agent is joined in 10 seconds")
            return
        }
        
        if AppContext.stateManager().agentState != .connected {
            addLog("agent is not joined in 10 seconds")
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Join.joinTimeoutTips)
            self.stopLoading()
            self.stopAgent()
        }
        
        timerCoordinator.stopJoinChannelTimer()
    }
}

