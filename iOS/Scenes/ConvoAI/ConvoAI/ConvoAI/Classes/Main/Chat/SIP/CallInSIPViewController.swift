//
//  CallInSIPViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common
import SnapKit

class CallInSIPViewController: SIPViewController {
    
    // MARK: - UI Components
    private let sipView = SIPPhoneListView()
    private let tipsView: SIPCallTipsView = {
        let view = SIPCallTipsView()
        view.infoLabel.text = ResourceManager.L10n.Sip.sipCallInTips
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func setupViews() {
        super.setupViews()
        view.addSubview(sipView)
        view.addSubview(tipsView)
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        
        sipView.snp.makeConstraints { make in
            make.bottom.equalTo(tipsView.snp.top).offset(-10)
            make.left.equalTo(44)
            make.right.equalTo(-44)
        }
        
        tipsView.snp.makeConstraints { make in
            make.bottom.equalTo(-112)
            make.left.equalToSuperview().offset(41)
            make.right.equalToSuperview().offset(-41)
        }
    }
}
