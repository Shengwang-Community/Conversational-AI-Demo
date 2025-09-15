//
//  DigitalHumanCell.swift
//  ConvoAI
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common

class DigitalHumanCell: UICollectionViewCell {
    static let identifier = "DigitalHumanCell"
    
    // MARK: - UI Components
    private lazy var containerButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.themColor(named: "ai_line1")
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        return button
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private lazy var nameBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.backgroundColor = UIColor.themColor(named: "ai_brand_black3")
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white
        label.textAlignment = .left
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var selectionIndicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_digital_human_circle")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private lazy var vendorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        view.layer.cornerRadius = 6
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var vendorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        return label
    }()
    
    // MARK: - Properties
    private var digitalHuman: DigitalHuman?
    var onSelectionChanged: ((DigitalHuman) -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        contentView.addSubview(containerButton)
        containerButton.addSubview(avatarImageView)
        containerButton.addSubview(nameBackgroundView)
        nameBackgroundView.addSubview(nameLabel)
        nameBackgroundView.addSubview(selectionIndicatorView)
        
        // Add vendor view to container button
        contentView.addSubview(vendorView)
        vendorView.addSubview(vendorLabel)
    }
    
    private func setupConstraints() {
        containerButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
                
        nameBackgroundView.snp.makeConstraints { make in
            make.left.equalTo(3)
            make.right.equalTo(-3)
            make.bottom.equalTo(-3)
            make.height.equalTo(36)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(8)
            make.right.equalTo(selectionIndicatorView.snp.left).offset(-10)
            make.centerY.equalToSuperview()
        }
        
        selectionIndicatorView.snp.makeConstraints { make in
            make.right.equalTo(-6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        vendorView.snp.makeConstraints { make in
            make.top.equalTo(4)
            make.right.equalTo(-4)
            make.height.equalTo(20)
        }
        
        vendorLabel.snp.makeConstraints { make in
            make.left.equalTo(6)
            make.right.equalTo(-6)
            make.centerY.equalToSuperview()
        }
    }
    
    private func setupActions() {
        containerButton.addTarget(self, action: #selector(onSelectionTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with digitalHuman: DigitalHuman) {
        self.digitalHuman = digitalHuman
        
        // Set name
        nameLabel.text = digitalHuman.avatar.avatarName
        
        if let vendor = digitalHuman.avatar.displayVendor {
            vendorView.isHidden = false
            vendorLabel.text = vendor
        } else {
            vendorView.isHidden = true
        }
        // Load avatar image
        if let thumbImageUrl = digitalHuman.avatar.thumbImageUrl,
           !thumbImageUrl.isEmpty,
           let url = URL(string: thumbImageUrl) {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = nil
        }
        
        // Update selection state
        updateSelectionState()
    }
    
    private func updateSelectionState() {
        guard let digitalHuman = digitalHuman else { return }
        
        if digitalHuman.isSelected {
            // Selected state
            containerButton.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
            selectionIndicatorView.image = UIImage.ag_named("ic_digital_human_circle_s")
        } else {
            // Unselected state
            containerButton.layer.borderColor = UIColor.clear.cgColor
            selectionIndicatorView.image = UIImage.ag_named("ic_digital_human_circle")
        }
    }
    
    // MARK: - Actions
    @objc private func onSelectionTapped() {
        guard let digitalHuman = digitalHuman else { return }
        onSelectionChanged?(digitalHuman)
    }
} 
