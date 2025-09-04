//
//  MineTabListView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit

// MARK: - MineTabListViewDelegate
protocol MineTabListViewDelegate: AnyObject {
    func mineTabListViewDidTapPrivacy()
    func mineTabListViewDidTapSettings()
}

class MineTabListView: UIView {
    
    // MARK: - Properties
    weak var delegate: MineTabListViewDelegate?
    
    private var settingItems: [UIView] = []
    
    // MARK: - UI Components
    
    // Settings Container View
    private lazy var settingsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layerCornerRadius = 10
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    // Privacy Item
    private lazy var privacyItem: MineSettingItemView = {
        let view = MineSettingItemView(frame: .zero)
        view.titleLabel.text = "隐私"
        view.iconImageView.image = UIImage.ag_named("ic_mine_privacy")
        view.button.addTarget(self, action: #selector(onTapPrivacy(_:)), for: .touchUpInside)
        return view
    }()
    
    // Settings Item
    private lazy var settingsItem: MineSettingItemView = {
        let view = MineSettingItemView(frame: .zero)
        view.titleLabel.text = "设置"
        view.iconImageView.image = UIImage.ag_named("ic_mine_setting")
        view.button.addTarget(self, action: #selector(onTapSettings(_:)), for: .touchUpInside)
        view.bottomLine.isHidden = true
        return view
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        backgroundColor = .clear
        
        settingItems = [privacyItem, settingsItem]
        
        addSubview(settingsContainerView)
        settingItems.forEach { settingsContainerView.addSubview($0) }
    }
    
    private func setupConstraints() {
        settingsContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        for (index, item) in settingItems.enumerated() {
            item.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.height.equalTo(50)
                
                if index == 0 {
                    make.top.equalToSuperview()
                } else {
                    make.top.equalTo(settingItems[index - 1].snp.bottom)
                }
                
                if index == settingItems.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func reloadData() {
        // Refresh data if needed
    }
    
    // MARK: - Action Methods
    @objc private func onTapPrivacy(_ sender: UIButton) {
        delegate?.mineTabListViewDidTapPrivacy()
    }
    
    @objc private func onTapSettings(_ sender: UIButton) {
        delegate?.mineTabListViewDidTapSettings()
    }
}

// MARK: - MineSettingItemView Component
class MineSettingItemView: UIView {
    
    // MARK: - UI Components
    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.themColor(named: "ai_brand_main6")
        return imageView
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        return label
    }()
    
    let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_info_arrow")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_line1")
        return view
    }()
    
    let button: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
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
        backgroundColor = UIColor.themColor(named: "ai_block2")
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(arrowImageView)
        addSubview(bottomLine)
        addSubview(button)
    }
    
    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(16)
            make.centerY.equalToSuperview()
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        bottomLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalToSuperview()
        }
        
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

