//
//  ChatViewController+DigitalHuman.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/3.
//

import Foundation
import AgoraRtcKit
import Common
import AlamofireImage

extension ChatViewController {
    internal func startShowAvatar() {
        windowState.showAvatar = true
        if let avatar = AppContext.preferenceManager()?.preference.avatar, let url = URL(string: avatar.bgImageUrl) {
            remoteAvatarView.backgroundImageView.af.setImage(withURL: url)
        }
        updateWindowContent()
    }
    
    internal func startRenderRemoteVideoStream() {
        startRenderRemoteVideoStream(renderView: remoteAvatarView.renderView)
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
