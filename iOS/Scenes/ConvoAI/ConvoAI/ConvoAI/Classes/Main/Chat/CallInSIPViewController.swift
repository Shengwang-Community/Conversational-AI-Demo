//
//  CallInSIPViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common

class CallInSIPViewController: SIPViewController {
    let sipView = SIPPhoneListView()

    // MARK: - UI Components
    private lazy var infoIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_aivad_tips_icon")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.sipCallInTips
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 10)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var infoStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [infoIcon, infoLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.backgroundColor = UIColor.clear
        stackView.layer.cornerRadius = 8
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func setupViews() {
        super.setupViews()
        view.addSubview(infoStackView)
        view.addSubview(sipView)
    }
    
    override func setupConstraints() {
        super.setupConstraints()
        infoStackView.snp.makeConstraints { make in
            make.bottom.equalTo(-112)
            make.left.equalToSuperview().offset(41)
            make.right.equalToSuperview().offset(-41)
        }
        
        sipView.snp.makeConstraints { make in
            make.bottom.equalTo(infoStackView.snp.top).offset(-10)
            make.left.equalTo(44)
            make.right.equalTo(-44)
        }
    }
}
