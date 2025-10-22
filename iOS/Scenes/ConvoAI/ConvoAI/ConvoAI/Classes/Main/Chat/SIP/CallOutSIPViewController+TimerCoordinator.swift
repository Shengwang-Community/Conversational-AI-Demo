//
//  CallOutSIPViewController+TimerCoordinator.swift
//  ConvoAI
//
//  Created by AI Assistant on 2025/10/22.
//

import Foundation
import SVProgressHUD
import Common

// MARK: - AgentTimerCoordinatorDelegate
extension CallOutSipViewController: AgentTimerCoordinatorDelegate {
    func agentUseLimitedTimerClosed() {
        sideNavigationBar.stop()
    }
    
    func agentUseLimitedTimerStarted(duration: Int) {
        addLog("[SIP Call] agentUseLimitedTimerStarted: \(duration)s")
        // Note: UI display is handled in fetchSIPState() with forever:true mode
        // We don't update the UI here to keep the display static
    }
    
    func agentUseLimitedTimerUpdated(duration: Int) {
        // Don't update UI - SIP calls show static time display (forever mode)
        // Timer still tracks duration in background for automatic call termination
    }
    
    func agentUseLimitedTimerEnd() {
        addLog("[SIP Call] agentUseLimitedTimerEnd - Call time limit reached")
        sideNavigationBar.stop()
        
        // End the SIP call
        closeConnect()
        
        // Show timeout alert
        let title = ResourceManager.L10n.ChannelInfo.timeLimitdAlertTitle
        if let preset = AppContext.settingManager().preset, let callTimeLimitSecond = preset.callTimeLimitSecond {
            let min = callTimeLimitSecond / 60
            TimeoutAlertView.show(
                in: view,
                image: UIImage.ag_named("ic_alert_timeout_icon"),
                title: title,
                description: String(format: ResourceManager.L10n.ChannelInfo.timeLimitdAlertDescription, min)
            )
        }
    }
    
    func agentStartPing() {
        // SIP calls don't need ping mechanism
        addLog("[SIP Call] agentStartPing - Not needed for SIP")
    }
    
    func agentNotJoinedWithinTheScheduledTime() {
        // SIP has its own timeout mechanism with fetchSIPState
        addLog("[SIP Call] agentNotJoinedWithinTheScheduledTime - Handled by sipTimeout")
    }
}

