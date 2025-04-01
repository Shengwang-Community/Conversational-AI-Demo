//
//  AgentTimerCoordinator.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/21.
//

import Foundation
import Common

protocol AgentTimerCoordinatorDelegate: AnyObject {
    func agentStartPing()
    func agentNotJoinedWithinTheScheduledTime()
    func agentUseLimitedTimerStarted(duration: Int)
    func agentUseLimitedTimerUpdated(duration: Int)
    func agentUseLimitedTimerEnd()
    func agentUseLimitedTimerClosed()
}

protocol AgentTimerCoordinatorProtocol {
    func startPingTimer()
    func stopPingTimer()
    
    func startJoinChannelTimer()
    func stopJoinChannelTimer()
    
    func startUsageDurationLimitTimer()
    func stopUsageDurationLimitTimer()
    
    func stopAllTimer()
    
    func setDurationLimit(limited: Bool)
}

class AgentTimerCoordinator: NSObject {
    // MARK: - Properties
    weak var delegate: AgentTimerCoordinatorDelegate?
    
    // MARK: - Private Properties
    private var pingTimer: Timer?
    private var joinChannelTimer: Timer?
    private var usageDurationLimitTimer: Timer?
    
    private var useDuration = 0
    private var isDurationLimited = true
    
    // Timer configuration constants
    private let pingTimeInterval = 10.0
    private let joinChannelTimeInterval = 30.0
    
    // MARK: - Duration Limit Timer
    private func initDurationLimitTimer() {
        guard let manager = AppContext.preferenceManager(),
              let preset = manager.preference.preset else {
            return
        }
        
        useDuration = isDurationLimited ? preset.callTimeLimitSecond : 60 * 10
        deinitDurationLimitTimer()
        
        usageDurationLimitTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleDurationLimitTimerTick),
            userInfo: nil,
            repeats: true
        )
        
        // Make sure timer runs even during UI interactions
        RunLoop.current.add(usageDurationLimitTimer!, forMode: .common)
        
        self.delegate?.agentUseLimitedTimerStarted(duration: useDuration)
    }
    
    @objc private func handleDurationLimitTimerTick() {
        if isDurationLimited {
            if useDuration <= 0 {
                usageDurationLimitTimer?.invalidate()
                usageDurationLimitTimer = nil
                delegate?.agentUseLimitedTimerEnd()
                delegate?.agentUseLimitedTimerClosed()
            } else {
                delegate?.agentUseLimitedTimerUpdated(duration: useDuration)
                useDuration -= 1
            }
        } else {
            useDuration += 1
            delegate?.agentUseLimitedTimerUpdated(duration: useDuration)
        }
    }
    
    private func deinitDurationLimitTimer() {
        guard usageDurationLimitTimer != nil else { return }
        
        usageDurationLimitTimer?.invalidate()
        usageDurationLimitTimer = nil
        delegate?.agentUseLimitedTimerClosed()
    }
    
    // MARK: - Ping Timer
    private func initPingTimer() {
        pingTimer = Timer.scheduledTimer(
            timeInterval: pingTimeInterval,
            target: self,
            selector: #selector(handlePingTimerTick),
            userInfo: nil,
            repeats: true
        )
        
        // Make sure timer runs even during UI interactions
        RunLoop.current.add(pingTimer!, forMode: .common)
    }
    
    @objc private func handlePingTimerTick() {
        delegate?.agentStartPing()
    }
    
    private func deinitPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    // MARK: - Join Channel Timer
    private var joinChannelCounter = 0
    
    private func initJoinChannelTimer() {
        deinitJoinChannelTimer()
        
        joinChannelCounter = 0
        
        joinChannelTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleJoinChannelTimerCountTick),
            userInfo: nil,
            repeats: true
        )
        
        RunLoop.current.add(joinChannelTimer!, forMode: .common)
    }
    
    @objc private func handleJoinChannelTimerCountTick() {
        joinChannelCounter += 1
        
        if joinChannelCounter >= 30 {
            joinChannelCounter = 0
            delegate?.agentNotJoinedWithinTheScheduledTime()
        }
    }
    
    private func deinitJoinChannelTimer() {
        joinChannelTimer?.invalidate()
        joinChannelTimer = nil
        joinChannelCounter = 0
    }
}

// MARK: - AgentTimerCoordinatorProtocol
extension AgentTimerCoordinator: AgentTimerCoordinatorProtocol {
    func startPingTimer() {
        stopPingTimer() // Ensure no duplicate timers
        initPingTimer()
    }
    
    func stopPingTimer() {
        deinitPingTimer()
    }
    
    func startJoinChannelTimer() {
        stopJoinChannelTimer() // Ensure no duplicate timers
        initJoinChannelTimer()
    }
    
    func stopJoinChannelTimer() {
        deinitJoinChannelTimer()
    }
    
    func startUsageDurationLimitTimer() {
        initDurationLimitTimer()
    }
    
    func stopUsageDurationLimitTimer() {
        deinitDurationLimitTimer()
    }
    
    func stopAllTimer() {
        deinitPingTimer()
        deinitJoinChannelTimer()
        deinitDurationLimitTimer()
    }
    
    func setDurationLimit(limited: Bool) {
        isDurationLimited = limited
        // if timer is running, reinit it
        if usageDurationLimitTimer != nil {
            initDurationLimitTimer()
        }
    }
}
