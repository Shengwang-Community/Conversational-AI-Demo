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
    private let bundleIdLabel = UILabel()
    public let bundleIdValueLabel = UILabel()
    private let rtcVersionLabel = UILabel()
    public let rtcVersionValueLabel = UILabel()
    
    // RTM Version - vertical layout
    public var rtmStackView: UIStackView!
    private let rtmTitleLabel = UILabel()
    public let rtmVersionValueLabel = UILabel()
    
    // env selection - vertical layout
    private let envContainerView = UIView()
    private let envTitleLabel = UILabel()
    public let envValueLabel = UILabel()
    public let envDetailLabel = UILabel()
    private let envArrowImageView = UIImageView()
    public let envMenuButton = UIButton(type: .custom)
    
    // AppID selection - vertical layout
    private let appIdContainerView = UIView()
    private let appIdTitleLabel = UILabel()
    public let appIdValueLabel = UILabel()
    private let appIdArrowImageView = UIImageView()
    public let appIdMenuButton = UIButton(type: .custom)
    
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
        
        // Bundle ID
        bundleIdLabel.text = "Bundle ID"
        bundleIdLabel.textColor = .white
        bundleIdLabel.font = UIFont.systemFont(ofSize: 16)
        bundleIdValueLabel.textColor = .lightGray
        bundleIdValueLabel.font = UIFont.systemFont(ofSize: 16)
        bundleIdValueLabel.text = Bundle.main.bundleIdentifier ?? "Unknown"
        let bundleIdStack = UIStackView(arrangedSubviews: [bundleIdLabel, bundleIdValueLabel])
        bundleIdStack.axis = .horizontal
        bundleIdStack.distribution = .equalSpacing
        stackView.addArrangedSubview(bundleIdStack)
        bundleIdStack.snp.makeConstraints { make in
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
        // RTM Version - Vertical Layout with StackView
        rtmTitleLabel.text = ResourceManager.L10n.DevMode.rtm
        rtmTitleLabel.textColor = .white
        rtmTitleLabel.font = UIFont.systemFont(ofSize: 16)
        rtmTitleLabel.numberOfLines = 0
        
        rtmVersionValueLabel.text = "2.2.3"
        rtmVersionValueLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        rtmVersionValueLabel.font = UIFont.systemFont(ofSize: 14)
        rtmVersionValueLabel.numberOfLines = 0
        
        rtmStackView = UIStackView(arrangedSubviews: [rtmTitleLabel, rtmVersionValueLabel])
        rtmStackView.axis = .vertical
        rtmStackView.spacing = 8
        rtmStackView.alignment = .leading
        rtmStackView.distribution = .fill
        stackView.addArrangedSubview(rtmStackView)
        
        rtmStackView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(60)
        }
        
        // env Selection - Vertical Layout
        stackView.addArrangedSubview(envContainerView)
        
        envTitleLabel.text = ResourceManager.L10n.DevMode.serverSwitch
        envTitleLabel.textColor = .white
        envTitleLabel.font = UIFont.systemFont(ofSize: 16)
        envTitleLabel.numberOfLines = 0
        envContainerView.addSubview(envTitleLabel)
        
        envValueLabel.text = "Prod"
        envValueLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        envValueLabel.font = UIFont.systemFont(ofSize: 14)
        envValueLabel.numberOfLines = 0
        envContainerView.addSubview(envValueLabel)
        
        envDetailLabel.text = ""
        envDetailLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        envDetailLabel.font = UIFont.systemFont(ofSize: 12)
        envDetailLabel.numberOfLines = 0
        envContainerView.addSubview(envDetailLabel)
        
        envArrowImageView.image = UIImage(systemName: "chevron.right")
        envArrowImageView.tintColor = UIColor.themColor(named: "ai_icontext1")
        envArrowImageView.contentMode = .scaleAspectFit
        envContainerView.addSubview(envArrowImageView)
        
        envMenuButton.backgroundColor = .clear
        envContainerView.addSubview(envMenuButton)
        
        envTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
        }
        
        envValueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(envTitleLabel)
            make.left.equalTo(envTitleLabel.snp.right).offset(8)
        }
        
        envDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(envTitleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview()
            make.right.equalTo(envArrowImageView.snp.left).offset(-12)
            make.bottom.equalToSuperview()
        }
        
        envArrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        envMenuButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        envContainerView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(60)
        }
        
        // AppID Selection - Vertical Layout
        stackView.addArrangedSubview(appIdContainerView)
        
        appIdTitleLabel.text = "VID-AppID"
        appIdTitleLabel.textColor = .white
        appIdTitleLabel.font = UIFont.systemFont(ofSize: 16)
        appIdTitleLabel.numberOfLines = 0
        appIdContainerView.addSubview(appIdTitleLabel)
        
        appIdValueLabel.text = "Select App ID"
        appIdValueLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        appIdValueLabel.font = UIFont.systemFont(ofSize: 14)
        appIdValueLabel.numberOfLines = 0
        appIdContainerView.addSubview(appIdValueLabel)
        
        appIdArrowImageView.image = UIImage(systemName: "chevron.right")
        appIdArrowImageView.tintColor = UIColor.themColor(named: "ai_icontext1")
        appIdArrowImageView.contentMode = .scaleAspectFit
        appIdContainerView.addSubview(appIdArrowImageView)
        
        appIdMenuButton.backgroundColor = .clear
        appIdContainerView.addSubview(appIdMenuButton)
        
        appIdTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalTo(appIdArrowImageView.snp.left).offset(-12)
        }
        
        appIdValueLabel.snp.makeConstraints { make in
            make.top.equalTo(appIdTitleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview()
            make.right.equalTo(appIdArrowImageView.snp.left).offset(-12)
            make.bottom.equalToSuperview()
        }
        
        appIdArrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        appIdMenuButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        appIdContainerView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(60)
        }
    }
}
