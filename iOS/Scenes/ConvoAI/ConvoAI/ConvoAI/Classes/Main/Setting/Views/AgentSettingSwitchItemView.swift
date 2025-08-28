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
    private let switcher = UISwitch()
    let bottomLine = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        createViews()
        createConstrains()
        updateViewState()
    }
    
    public func addtarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        switcher.addTarget(target, action: action, for: controlEvents)
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
}

extension AgentSettingSwitchItemView {
    
    private func createViews() {
        self.backgroundColor = UIColor.themColor(named: "ai_block2")

        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        addSubview(titleLabel)
        
        detailLabel.textColor = UIColor.themColor(named: "ai_icontext3")
        detailLabel.font = UIFont.systemFont(ofSize: 12)
        addSubview(detailLabel)
        
        bottomLine.backgroundColor = UIColor.themColor(named: "ai_line1")
        addSubview(bottomLine)
        
        addSubview(switcher)
        
        switcher.onTintColor = UIColor.themColor(named: "ai_brand_main6")
        switcher.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        switcher.layer.cornerRadius = switcher.frame.height / 2
        switcher.clipsToBounds = true
        switcher.addTarget(self, action: #selector(switcherValueChanged(_:)), for: .valueChanged)
    }
    
    private func createConstrains() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }
        detailLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        switcher.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
        }
        bottomLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
    }
    
    func updateLayout() {
        if let text = detailLabel.text, !text.isEmpty {
            detailLabel.isHidden = false
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(16)
                make.bottom.equalTo(self.snp.centerY)
            }
        } else {
            detailLabel.isHidden = true
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(16)
                make.centerY.equalToSuperview()
            }
        }
    }
    
    private func updateViewState() {
        let isOn = switcher.isOn
        let enable = switcher.isEnabled
        if (isOn && enable) {
            switcher.onTintColor = UIColor.themColor(named: "ai_brand_main6")
            switcher.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        } else if (isOn && !enable) {
            switcher.onTintColor = UIColor.themColor(named: "ai_disable")
            switcher.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        } else if (!isOn && enable) {
            switcher.tintColor = UIColor.themColor(named: "ai_line2")
            switcher.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        } else {
            switcher.onTintColor = UIColor.themColor(named: "ai_disable")
            switcher.backgroundColor = UIColor.themColor(named: "ai_brand_white6")
        }
        switcher.isOn = isOn
    }
}

