//
//  ChatViewController+DigitalHuman.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/3.
//

import Foundation
import AgoraRtcKit
import Common
import Kingfisher

extension ChatViewController {
    internal func startShowAvatar() {
        windowState.showAvatar = true
        if let avatar = AppContext.settingManager().avatar, let url = URL(string: avatar.bgImageUrl.stringValue()) {
            remoteAvatarView.backgroundImageView.kf.setImage(with: url)
        } else {
            remoteAvatarView.backgroundImageView.image = UIImage.ag_named("img_avatar_place_holder")
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
    
    internal func isEnableAvatar() -> Bool {
        let preset = AppContext.settingManager().preset
        let isPresetSupportAvatar = preset?.isSupportAvatar == true
        return AppContext.shared.avatarEnable || AppContext.settingManager().avatar != nil || isPresetSupportAvatar
    }
}
