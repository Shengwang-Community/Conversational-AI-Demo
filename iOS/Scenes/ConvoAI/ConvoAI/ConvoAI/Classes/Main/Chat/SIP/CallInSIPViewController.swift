//
//  CallInphoneListViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common
import SnapKit

class CallInSIPViewController: SIPViewController {
    
    private let phoneListView = SIPPhoneListView()
    private lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallInTips
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 10)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phoneListView.delegate = self
        setupPhoneData()
    }
    
    private func setupPhoneData() {
        guard let preset = AppContext.settingManager().preset, let vendorCalleeNumbers = preset.sipVendorCalleeNumbers else {
            return
        }
        
        let phoneNumbers = vendorCalleeNumbers.compactMap { (vendor) -> PhoneNumber? in
            guard let regionName = vendor.regionName, let phoneNumber = vendor.phoneNumber else {
                return nil
            }
            
            guard let regionConfig = RegionConfigManager.shared.getRegionConfigByName(regionName) else {
                return nil
            }
            
            return PhoneNumber(regionName: regionConfig.regionName, flagEmoji: regionConfig.flagEmoji, phoneNumber: phoneNumber)
        }
        
        phoneListView.updatePhoneNumbers(phoneNumbers)
    }
    
    override func setupViews() {
        super.setupViews()
        view.addSubview(phoneListView)
        view.addSubview(tipsLabel)
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        
        phoneListView.snp.makeConstraints { make in
            make.bottom.equalTo(tipsLabel.snp.top).offset(-18)
            make.left.equalTo(44)
            make.right.equalTo(-44)
        }
        
        tipsLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.left.equalToSuperview().offset(41)
            make.right.equalToSuperview().offset(-41)
        }
    }
}

// MARK: - SIPPhoneListViewDelegate
extension CallInSIPViewController: SIPPhoneListViewDelegate {
    func sipPhoneListView(_ listView: SIPPhoneListView, didSelectPhoneNumber phoneNumber: PhoneNumber, at index: Int) {
        print("Selected phone number: \(phoneNumber.displayNumber) at index: \(index)")
        makePhoneCall(phoneNumber: phoneNumber.phoneNumber)
    }
    
    private func makePhoneCall(phoneNumber: String) {
        AgentAlertView.show(
            in: self.view,
            title: ResourceManager.L10n.Sip.callAlertTitle,
            content: ResourceManager.L10n.Sip.callAlertMessage,
            cancelTitle: ResourceManager.L10n.Sip.callAlertCancel,
            confirmTitle: ResourceManager.L10n.Sip.callAlertConfirm,
            type: .normal,
            onConfirm: {
                let cleanedNumber = phoneNumber.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                
                if let phoneURL = URL(string: "tel://\(cleanedNumber)") {
                    if UIApplication.shared.canOpenURL(phoneURL) {
                        UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
                    }
                }
            },
            onCancel: nil
        )
    }
}
