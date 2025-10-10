//
//  AgentSettingView.swift
//  Agent
//
//  Created by HeZhengQing on 2024/9/30.
//

import UIKit
import Common
import SVProgressHUD

class AgentSettingTableItemView: UIView {
    let titleLabel = UILabel()
    let detailLabel = UILabel()
    private let imageView = UIImageView(image: UIImage.ag_named("ic_agent_setting_tab"))
    let bottomLine = UIView()
    let button = UIButton(type: .custom)
    
    var enableLongPressCopy: Bool = false {
        didSet {
            updateLongPressGesture()
        }
    }
    
    private var longPressGesture: UILongPressGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createViews()
        createConstrains()
        setupLongPressGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func onClickButton(_ sender: UIButton) {
        print("click button")
    }
    
    func setImageViewHiddenState(state: Bool) {
        imageView.isHidden = state
        
        if state {
            detailLabel.snp.remakeConstraints { make in
                make.right.equalTo(-16)
                make.width.lessThanOrEqualTo(200)
                make.centerY.equalToSuperview()
            }
        } else {
            detailLabel.snp.remakeConstraints { make in
                make.right.equalTo(imageView.snp.left).offset(-8)
                make.width.lessThanOrEqualTo(200)
                make.centerY.equalToSuperview()
            }
        }
    }
    
    private func setupLongPressGesture() {
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        updateLongPressGesture()
    }
    
    private func updateLongPressGesture() {
        if enableLongPressCopy {
            if let gesture = longPressGesture {
                detailLabel.isUserInteractionEnabled = true
                detailLabel.addGestureRecognizer(gesture)
            }
        } else {
            if let gesture = longPressGesture {
                detailLabel.removeGestureRecognizer(gesture)
                detailLabel.isUserInteractionEnabled = false
            }
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            if let text = detailLabel.text, !text.isEmpty {
                UIPasteboard.general.string = text
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.ChannelInfo.copyToast)
            }
        }
    }
    
    func setEnable(_ enable: Bool) {
        button.isEnabled = enable
        if enable {
            detailLabel.textColor = UIColor.white
        } else {
            detailLabel.textColor = UIColor.themColor(named: "ai_icontext4")
        }
    }
}

extension AgentSettingTableItemView {
    private func createViews() {
        self.backgroundColor = UIColor.themColor(named: "ai_block2")

        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        addSubview(titleLabel)
        
        detailLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        detailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .right
        
        addSubview(detailLabel)
        
        addSubview(imageView)
        
        bottomLine.backgroundColor = UIColor.themColor(named: "ai_line1")
        addSubview(bottomLine)
        
        addSubview(button)
    }
    
    private func createConstrains() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
        }
        detailLabel.snp.makeConstraints { make in
            make.right.equalTo(imageView.snp.left).offset(-8)
            make.width.lessThanOrEqualTo(200)
            make.centerY.equalToSuperview()
        }
        bottomLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
        button.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
        }
    }
    
    func bottomLineStyle2() {
        bottomLine.snp.remakeConstraints { make in
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
    }
}
// MARK: - AgentSettingTextItemView
class AgentSettingTextItemView: UIView {
    let titleLabel = UILabel()
    let detailLabel = UILabel()
    let bottomLine = UIView()
    let button = UIButton(type: .custom)
    
    var enableLongPressCopy: Bool = false {
        didSet {
            updateLongPressGesture()
        }
    }
    
    private var longPressGesture: UILongPressGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createViews()
        createConstrains()
        updateEnableState()
        setupLongPressGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func onClickButton(_ sender: UIButton) {
        print("click button")
    }
    
    private func setupLongPressGesture() {
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        updateLongPressGesture()
    }
    
    private func updateLongPressGesture() {
        if enableLongPressCopy {
            if let gesture = longPressGesture {
                detailLabel.isUserInteractionEnabled = true
                detailLabel.addGestureRecognizer(gesture)
            }
        } else {
            if let gesture = longPressGesture {
                detailLabel.removeGestureRecognizer(gesture)
                detailLabel.isUserInteractionEnabled = false
            }
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            if let text = detailLabel.text, !text.isEmpty {
                UIPasteboard.general.string = text
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.ChannelInfo.copyToast)
            }
        }
    }
}

extension AgentSettingTextItemView {
    private func createViews() {
        self.backgroundColor = UIColor.themColor(named: "ai_block2")

        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        addSubview(titleLabel)
        
        detailLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        detailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .right
        
        addSubview(detailLabel)
                
        bottomLine.backgroundColor = UIColor.themColor(named: "ai_line1")
        addSubview(bottomLine)
        
        addSubview(button)
    }
    
    private func createConstrains() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalTo(detailLabel.snp.left).offset(-10)
            make.centerY.equalToSuperview()
        }
        detailLabel.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.width.lessThanOrEqualTo(200)
            make.centerY.equalToSuperview()
        }
        bottomLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
        button.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
        }
    }
    
    func updateEnableState() {
        let state = AppContext.stateManager().agentState == .unload
        button.isEnabled = state
        detailLabel.textColor = state ? UIColor.themColor(named: "ai_icontext1") : UIColor.themColor(named: "ai_icontext1").withAlphaComponent(0.3)
    }
}
