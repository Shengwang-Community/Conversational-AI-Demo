//
//  ChatViewController+CreateUi.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/1.
//

import Foundation
import Common

class ChatWindowState {
    var showTranscription = false
    var showAvatar = false
    var showVideo = false
    
    func reset() {
        showTranscription = false
        if AppContext.shared.avatarEnable || AppContext.preferenceManager()?.preference.avatar != nil {
            showAvatar = true
        } else {
            showAvatar = false
        }
        showVideo = false
    }
}

extension ChatViewController {
    internal func setupViews() {
        view.backgroundColor = .black
        naviBar.isHidden = true
        [animateContentView, fullSizeContainerView, upperBackgroundView, lowerBackgroundView, messageMaskView, messageView, smallSizeContainerView, agentStateView, navivationBar, sideNavigationBar, callControlBar, volumeAnimateView, annotationView, sendMessageButton].forEach { view.addSubview($0) }

        [miniView].forEach { smallSizeContainerView.addSubview($0) }
        [remoteAvatarView].forEach { miniView.addSubview($0) }
        [localVideoView].forEach { fullSizeContainerView.addSubview($0) }
    }
    
    internal func setupConstraints() {
        navivationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(5)
            make.left.right.equalToSuperview()
            make.height.equalTo(48)
        }
        
        sideNavigationBar.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.height.equalTo(32)
            make.top.equalTo(navivationBar.snp.bottom)
        }
        
        volumeAnimateView.snp.makeConstraints { make in
            make.top.equalTo(navivationBar.snp.bottom).offset(0)
            make.centerX.equalToSuperview()
        }
        
        animateContentView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        fullSizeContainerView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        localVideoView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        callControlBar.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-30)
            make.left.right.equalTo(0)
            make.height.equalTo(76)
        }
        
        agentStateView.snp.makeConstraints { make in
            make.bottom.equalTo(callControlBar.snp.top).offset(-24)
            make.left.right.equalTo(0)
            make.height.equalTo(58)
        }
        
        messageMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        messageView.snp.makeConstraints { make in
            make.top.equalTo(navivationBar.snp.bottom).offset(22)
            make.left.right.equalTo(0)
            make.bottom.equalTo(agentStateView.snp.top)
        }
        
        smallSizeContainerView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        miniView.snp.makeConstraints { make in
            make.top.equalTo(215)
            make.right.equalTo(-10)
            make.width.equalTo(90)
            make.height.equalTo(130)
        }
        
        remoteAvatarView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        annotationView.snp.makeConstraints { make in
            make.bottom.equalTo(callControlBar.snp.top).offset(-94)
            make.left.right.equalTo(0)
            make.height.equalTo(44)
        }
        
        upperBackgroundView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(view.snp.centerY)
        }
        
        lowerBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(view.snp.centerY)
            make.left.right.bottom.equalToSuperview()
        }
        
        sendMessageButton.snp.makeConstraints { make in
            make.centerX.equalTo(view)
            make.centerY.equalTo(view)
        }
        
        updateWindowContent()
    }
    
    internal func didLayoutSubviews() {
        upperBackgroundView.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        lowerBackgroundView.layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = upperBackgroundView.bounds
        var startColor = UIColor.themColor(named: "ai_fill4")
        let middleColor = UIColor.themColor(named: "ai_fill4").withAlphaComponent(0.7)
        var endColor = UIColor.clear
        gradientLayer.colors = [startColor.cgColor, middleColor.cgColor, endColor.cgColor]
        
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.locations = [0.0, 0.2, 0.7]
        upperBackgroundView.layer.insertSublayer(gradientLayer, at: 0)
        
        let bottomGradientLayer = CAGradientLayer()
        startColor = UIColor.clear
        endColor = UIColor.themColor(named: "ai_fill4")
        bottomGradientLayer.frame = lowerBackgroundView.bounds
        bottomGradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        
        bottomGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomGradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomGradientLayer.locations = [0.0, 0.7]
        
        lowerBackgroundView.layer.insertSublayer(bottomGradientLayer, at: 0)
    }
    
    internal func viewWillAppear() {
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        let isLogin = UserCenter.shared.isLogin()
        navivationBar.updateButtonVisible(isLogin)
    }
        
    func resetUIDisplay() {
        setupMuteState(state: false)
        windowState.reset()
        animateView.updateAgentState(.idle)
        messageView.clearMessages()
        messageView.isHidden = true
        messageMaskView.isHidden = true
        callControlBar.resetState()
        timerCoordinator.stopAllTimer()
        agentStateView.isHidden = true
        sideNavigationBar.voiceprintState(status: false)
        updateWindowContent()
    }
    
    func updateWindowContent() {
        let showAvatar = windowState.showAvatar
        let showVideo = windowState.showVideo
        let showTranscription = windowState.showTranscription
        fullSizeContainerView.removeSubviews()
        miniView.removeSubviews()
        if showTranscription {
            if showAvatar, showVideo {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = false
                smallSizeContainerView.isHidden = false
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                animateContentView.isHidden = false
                fullSizeContainerView.addSubview(remoteAvatarView)
                miniView.addSubview(localVideoView)
                localVideoView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
                
                remoteAvatarView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else if showAvatar {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = false
                smallSizeContainerView.isHidden = true
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                animateContentView.isHidden = true
                fullSizeContainerView.addSubview(remoteAvatarView)
                remoteAvatarView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else if showVideo {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = true
                smallSizeContainerView.isHidden = false
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                animateContentView.isHidden = false
                miniView.addSubview(localVideoView)
                localVideoView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = true
                smallSizeContainerView.isHidden = true
                upperBackgroundView.isHidden = false
                lowerBackgroundView.isHidden = false
                animateContentView.isHidden = false
            }
        } else {
            if showAvatar, showVideo {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = false
                smallSizeContainerView.isHidden = false
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                animateContentView.isHidden = false
                fullSizeContainerView.addSubview(localVideoView)
                miniView.addSubview(remoteAvatarView)
                localVideoView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
                
                remoteAvatarView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else if showAvatar {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = false
                smallSizeContainerView.isHidden = true
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                animateContentView.isHidden = true
                fullSizeContainerView.addSubview(remoteAvatarView)
                remoteAvatarView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else if showVideo {
                fullSizeContainerView.isHidden = false
                smallSizeContainerView.isHidden = true
                upperBackgroundView.isHidden = true
                lowerBackgroundView.isHidden = true
                fullSizeContainerView.addSubview(localVideoView)
                volumeAnimateView.isHidden = false
                animateContentView.isHidden = false
                localVideoView.snp.makeConstraints { make in
                    make.edges.equalTo(UIEdgeInsets.zero)
                }
            } else {
                volumeAnimateView.isHidden = true
                fullSizeContainerView.isHidden = true
                smallSizeContainerView.isHidden = true
                upperBackgroundView.isHidden = false
                lowerBackgroundView.isHidden = false
                animateContentView.isHidden = false
            }
        }
        let isLight = !fullSizeContainerView.isHidden && !showTranscription
        callControlBar.setButtonColorTheme(showLight: isLight)
        navivationBar.setButtonColorTheme(showLight: isLight)
        sideNavigationBar.setButtonColorTheme(showLight: isLight)
    }
    
    @objc func smallWindowClicked() {
        if !windowState.showTranscription {
            return
        }
        
        showTranscription(state: false)
    }
}

extension ChatViewController: ChatViewDelegate {
    func resendImage(image: UIImage, uuid: String) {
        sendImage(image: image, isResend: true, uuid: uuid)
    }
}
