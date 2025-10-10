//
//  SIPViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import AgoraRtcKit
import Common

class SIPViewController: BaseViewController, AgoraRtcEngineDelegate {
    lazy var navivationBar: MainNavigationBar = {
        let view = MainNavigationBar()
        view.settingButton.isHidden = true
        view.wifiInfoButton.isHidden = true
        view.transcriptionButton.isHidden = true
        view.closeButton.addTarget(self, action: #selector(onCloseButton), for: .touchUpInside)
        return view
    }()

    lazy var rtcManager: RTCManager = {
        let manager = RTCManager()
        let _ = manager.createRtcEngine(delegate: self)
        return manager
    }()
    
    lazy var animateContentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill4")
        return view
    }()
    
    lazy var animateView: AnimateView = {
        let view = AnimateView(videoView: animateContentView)
        return view
    }()
    
    internal let upperBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    internal let lowerBackgroundView: UIView = {
        let view = UIView()
        return view
    }()
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        didLayoutSubviews()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMPK()
        setupViews()
        setupConstraints()
        updateCharacterInformation()
    }
    
    func setupMPK() {
        let rtcEngine = rtcManager.getRtcEntine()
        animateView.setupMediaPlayer(rtcEngine)
        animateView.updateAgentState(.idle)
    }

    func setupViews() {
        naviBar.isHidden = true
        [animateContentView, upperBackgroundView, lowerBackgroundView, navivationBar].forEach { view.addSubview($0) }
    }
    
    func setupConstraints() {
        navivationBar.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(5)
            make.left.right.equalToSuperview()
            make.height.equalTo(48)
        }
        
        animateContentView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalTo(0)
        }
        
        upperBackgroundView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(view.snp.centerY)
        }
        
        lowerBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(view.snp.centerY)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    func updateCharacterInformation() {
        if let preset = AppContext.settingManager().preset {
            navivationBar.updateCharacterInformation(
                icon: preset.avatarUrl.stringValue(),
                defaultIcon: preset.defaultAvatar ?? "",
                name: preset.displayName.stringValue()
            )
        }
    }
    
    @objc func onCloseButton() {
        self.navigationController?.popViewController(animated: true)
    }
}


