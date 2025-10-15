//
//  DeveloperBasicSettingView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/07/29.
//

import UIKit
import SnapKit
import Common

public class DeveloperBasicSettingView: UIView  {
    private let appVersionLabel = UILabel()
    public let appVersionValueLabel = UILabel()
    private let rtcVersionLabel = UILabel()
    public let rtcVersionValueLabel = UILabel()
    private let rtmVersionLabel = UILabel()
    public let rtmVersionValueLabel = UILabel()
    private let environmentLabel = UILabel()
    public let menuButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        backgroundColor = .clear
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
        }
        
        // App Version
        appVersionLabel.text = "App Version"
        appVersionLabel.textColor = .white
        appVersionLabel.font = UIFont.systemFont(ofSize: 16)
        appVersionValueLabel.textColor = .lightGray
        appVersionValueLabel.font = UIFont.systemFont(ofSize: 16)
        appVersionValueLabel.text = "\(ConversationalAIAPIImpl.version)(Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"
        let appStack = UIStackView(arrangedSubviews: [appVersionLabel, appVersionValueLabel])
        appStack.axis = .horizontal
        appStack.distribution = .equalSpacing
        stackView.addArrangedSubview(appStack)
        appStack.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        // RTC Version
        rtcVersionLabel.text = ResourceManager.L10n.DevMode.rtc
        rtcVersionLabel.textColor = .white
        rtcVersionLabel.font = UIFont.systemFont(ofSize: 16)
        rtcVersionValueLabel.textColor = .lightGray
        rtcVersionValueLabel.font = UIFont.systemFont(ofSize: 16)
        rtcVersionValueLabel.text = "4.5.1"
        let rtcStack = UIStackView(arrangedSubviews: [rtcVersionLabel, rtcVersionValueLabel])
        rtcStack.axis = .horizontal
        rtcStack.distribution = .equalSpacing
        stackView.addArrangedSubview(rtcStack)
        rtcStack.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        // RTM Version
        rtmVersionLabel.text = ResourceManager.L10n.DevMode.rtm
        rtmVersionLabel.textColor = .white
        rtmVersionLabel.font = UIFont.systemFont(ofSize: 16)
        rtmVersionValueLabel.textColor = .lightGray
        rtmVersionValueLabel.font = UIFont.systemFont(ofSize: 16)
        rtmVersionValueLabel.text = "2.2.3"
        let rtmStack = UIStackView(arrangedSubviews: [rtmVersionLabel, rtmVersionValueLabel])
        rtmStack.axis = .horizontal
        rtmStack.distribution = .equalSpacing
        stackView.addArrangedSubview(rtmStack)
        rtmStack.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        environmentLabel.text = ResourceManager.L10n.DevMode.serverSwitch
        environmentLabel.textColor = .white
        environmentLabel.font = UIFont.systemFont(ofSize: 16)
        menuButton.setTitle("Prod", for: .normal)
        menuButton.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        menuButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        menuButton.backgroundColor = UIColor.themColor(named: "ai_block2")
        menuButton.layer.cornerRadius = 4
        menuButton.layer.borderWidth = 1
        menuButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        menuButton.semanticContentAttribute = .forceRightToLeft
        menuButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        menuButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        let envStack = UIStackView(arrangedSubviews: [environmentLabel, menuButton])
        envStack.axis = .horizontal
        envStack.distribution = .equalSpacing
        envStack.alignment = .center
        stackView.addArrangedSubview(envStack)
        envStack.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }
}
