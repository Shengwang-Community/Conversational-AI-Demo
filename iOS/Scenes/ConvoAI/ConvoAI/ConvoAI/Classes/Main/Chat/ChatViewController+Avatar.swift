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
    internal func startShowAvatar() {
        windowState.showAvatar = true
        startRenderRemoteVideoStream(renderView: remoteAvatarView.renderView)
        updateWindowContent()
    }
    
    internal func stopShowAvatar() {
        windowState.showAvatar = false
        stopRenderRemoteViewStream()
        updateWindowContent()
    }
    
    internal func avatarIsSelected() -> Bool {
        return AppContext.preferenceManager()?.preference.avatar != nil
    }
}
