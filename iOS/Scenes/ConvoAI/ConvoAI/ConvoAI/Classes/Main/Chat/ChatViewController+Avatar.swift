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
import SVProgressHUD

extension ChatViewController {
    internal var isSpatiusAvatar: Bool {
        SpatiusConfig.isSelected(preset: AppContext.settingManager().preset,
                                 avatar: AppContext.settingManager().avatar)
    }

    @MainActor
    internal func prepareSpatiusAvatar() async throws {
        localAvatarSession?.close()
        localAvatarSession = nil
        guard isSpatiusAvatar else { return }
        guard #available(iOS 16.0, *) else {
            handleSpatiusFailure(.loadFailed)
            return
        }
        let session = SpatiusAvatarSession(onRenderReady: { [weak self] ready in
            self?.remoteAvatarView.setSpatiusRenderReady(ready)
        }, onFailure: { [weak self] failure in
            self?.handleSpatiusFailure(failure)
        })
        localAvatarSession = session
        let config = SpatiusConfig.resolve(preset: AppContext.settingManager().preset,
                                           avatar: AppContext.settingManager().avatar)
        try await session.prepare(config: config, container: remoteAvatarView.renderView,
                                  engine: rtcManager.getRtcEntine())
    }

    @MainActor
    internal func handleSpatiusFailure(_ failure: SpatiusRenderFailure) {
        guard callControlBar.style != .startButton else { return }
        stopLoading()
        stopAgent()
        let message = failure == .restartRequired
            ? "conversation.avatar.configuration.changed"
            : "conversation.avatar.render.failed"
        SVProgressHUD.showError(withStatus: ResourceManager.localizedString(message))
    }

    internal func startShowAvatar() {
        windowState.showAvatar = true
        remoteAvatarView.useSpatiusStage = isSpatiusAvatar
        let avatar = AppContext.settingManager().avatar
        let background = avatar?.bgImageUrl
        remoteAvatarView.backgroundImageView.kf.cancelDownloadTask()
        if let url = URL(string: background.stringValue()) {
            remoteAvatarView.backgroundImageView.kf.setImage(with: url,
                placeholder: UIImage.ag_named("img_avatar_place_holder"))
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
