//
//  AgentSettingView.swift
//  Agent
//
//  Created by HeZhengQing on 2024/9/30.
//

import UIKit
import Common

class AgentSettingSwitchItemView: UIView {
    let titleLabel = UILabel()
    let detailLabel = UILabel()
    public let switcher = UISwitch()
    let bottomLine = UIView()
    
    public let tipsButton = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createViews()
        createConstrains()
        updateViewState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switcher.layer.cornerRadius = switcher.bounds.height / 2.0
    }
    
    
    func setEnable(_ enable: Bool) {
        switcher.isEnabled = enable
        updateViewState()
    }
    
    func setOn(_ on: Bool) {
        switcher.isOn = on
        updateViewState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func switcherValueChanged(_ sender: UISwitch) {
        updateViewState()
    }
    
    private func createViews() {
        self.backgroundColor = UIColor.themColor(named: "ai_block2")

        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        addSubview(titleLabel)
        
        detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        detailLabel.font = UIFont.systemFont(ofSize: 12)
        addSubview(detailLabel)
        
        bottomLine.backgroundColor = UIColor.themColor(named: "ai_line1")
        addSubview(bottomLine)
        
        addSubview(switcher)
        
        switcher.onTintColor = UIColor.themColor(named: "ai_brand_main6")
        switcher.backgroundColor = .clear
        switcher.addTarget(self, action: #selector(switcherValueChanged(_:)), for: .valueChanged)
        
        // Setup tips button
        addSubview(tipsButton)
        tipsButton.isHidden = true
    }
    
    private func createConstrains() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(switcher.snp.left).offset(-32)
        }
        detailLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        switcher.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(51)
        }
        bottomLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
        tipsButton.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(8)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(16)
        }
    }
   
    
    private func updateViewState() {
        let isOn = switcher.isOn
        let enable = switcher.isEnabled
        if (isOn && enable) {
            switcher.onTintColor = UIColor.themColor(named: "ai_brand_main6")
            switcher.tintColor = UIColor.themColor(named: "ai_brand_main6")
            switcher.backgroundColor = .clear
        } else if (isOn && !enable) {
            switcher.onTintColor = UIColor.themColor(named: "ai_disable")
            switcher.tintColor = UIColor.themColor(named: "ai_disable")
            switcher.backgroundColor = .clear
        } else if (!isOn && enable) {
            switcher.tintColor = UIColor.themColor(named: "ai_line2")
            switcher.backgroundColor = .clear
        } else {
            switcher.onTintColor = UIColor.themColor(named: "ai_disable")
            switcher.tintColor = UIColor.themColor(named: "ai_disable")
            switcher.backgroundColor = .clear
        }
        switcher.isOn = isOn
    }
}
