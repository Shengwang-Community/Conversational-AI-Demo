//
//  MineIotView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit

// MARK: - MineIotViewDelegate
protocol MineIotViewDelegate: AnyObject {
    func mineIotViewDidTapAddDevice()
}

class MineIotView: UIView {
    
    // MARK: - Properties
    weak var delegate: MineIotViewDelegate?
    
    // MARK: - UI Components
    
    private lazy var devicesTitleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.iotDevicesTitle
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private lazy var devicesCardView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var devicesStatusLabel: UILabel = {
        let label = UILabel()
        label.text = String(format: ResourceManager.L10n.Mine.iotDevicesCount, 0)
        label.textColor = UIColor.themColor(named: "ai_brand_black8")
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .left
        return label
    }()
    
    private lazy var iotCardButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.ag_named("img_mine_iot_card"), for: .normal)
        button.contentMode = .scaleAspectFill
        button.addTarget(self, action: #selector(iotCardButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        backgroundColor = UIColor.themColor(named: "ai_fill2")
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        addSubview(devicesTitleLabel)
        addSubview(devicesCardView)
        devicesCardView.addSubview(iotCardButton)
        devicesCardView.addSubview(devicesStatusLabel)
    }
    
    private func setupConstraints() {       
        devicesTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(16)
        }
        devicesCardView.snp.makeConstraints { make in
            make.top.equalTo(devicesTitleLabel.snp.bottom).offset(15)
            make.bottom.equalToSuperview().offset(-16)
            make.left.right.equalToSuperview()
        }
        iotCardButton.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        devicesStatusLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(35)
        }
    }
    
    // MARK: - Actions
    @objc private func iotCardButtonTapped() {
        delegate?.mineIotViewDidTapAddDevice()
    }
    
    // MARK: - Public Methods
    func updateDeviceCount(_ count: Int) {
        devicesStatusLabel.text = String(format: ResourceManager.L10n.Mine.iotDevicesCount, count)
    }
}
