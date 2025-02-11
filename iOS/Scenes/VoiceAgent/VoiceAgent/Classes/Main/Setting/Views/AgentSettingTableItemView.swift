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
    let imageView = UIImageView(image: UIImage.va_named("ic_agent_setting_tab"))
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

extension AgentSettingTableItemView {
    private func createViews() {
        self.backgroundColor = PrimaryColors.c_1d1d1d

        titleLabel.textColor = PrimaryColors.c_ffffff
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        addSubview(titleLabel)
        
        detailLabel.textColor = PrimaryColors.c_ffffff
        detailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .right
        
        addSubview(detailLabel)
        
        addSubview(imageView)
        
        bottomLine.backgroundColor = PrimaryColors.c_27272a_a
        addSubview(bottomLine)
        
        addSubview(button)
    }
    
    private func createConstrains() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalTo(detailLabel.snp.left).offset(-10)
            make.centerY.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
        }
        detailLabel.snp.makeConstraints { make in
            make.right.equalTo(imageView.snp.left).offset(-8)
            make.left.equalTo(titleLabel.snp.right).offset(10)
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
    
    func updateEnableState() {
        guard let manager = AppContext.preferenceManager() else {
            return
        }
        
        let state = manager.information.agentState == .unload
        button.isEnabled = state
        detailLabel.textColor = state ? PrimaryColors.c_ffffff : PrimaryColors.c_ffffff.withAlphaComponent(0.3)
    }
}
