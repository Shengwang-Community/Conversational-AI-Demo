//
//  ChatViewController+DigitalHuman.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/3.
//

import Foundation
import AgoraRtcKit
import Common

extension ChatViewController {
    internal func startAvatar() {
        digitalHumanContainerView.isHidden = false
        animateContentView.isHidden = true
        
        startRenderRemoteVideoStream(renderView: digitalHumanContainerView)
    }
    
    internal func stopAvatar() {
        digitalHumanContainerView.isHidden = true
        animateContentView.isHidden = false
        
        stopRenderRemoteViewStream()
    }
    
    internal func avatarIsSelected() -> Bool {
        return AppContext.preferenceManager()?.preference.avatar != nil
    }
}
