//
//  DigitalHumanCell.swift
//  ConvoAI
//
//  Created by Assistant on 2024/12/19.
//

import UIKit
import Common
import AlamofireImage

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
        label.numberOfLines = 0
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
    
    private lazy var disabledIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_digital_human_close")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    private lazy var closeTitle: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Settings.digitalHumanClosed
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private lazy var closeStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [disabledIconView, closeTitle])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 14
        stackView.isHidden = true
        stackView.isUserInteractionEnabled = false
        return stackView
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
        containerButton.addSubview(closeStackView)
        containerButton.addSubview(nameBackgroundView)
        nameBackgroundView.addSubview(nameLabel)
        nameBackgroundView.addSubview(selectionIndicatorView)
    }
    
    private func setupConstraints() {
        containerButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        disabledIconView.snp.makeConstraints { make in
            make.width.height.equalTo(32)
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
    }
    
    private func setupActions() {
        containerButton.addTarget(self, action: #selector(onSelectionTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with digitalHuman: DigitalHuman) {
        self.digitalHuman = digitalHuman
        
        // Set name
        nameLabel.text = digitalHuman.avatar.avatarName
        // Configure avatar or disabled state
        if digitalHuman.avatar.avatarId == "close" {
            // Close option - show disabled icon with dark background
            avatarImageView.image = nil
            avatarImageView.backgroundColor = UIColor.systemGray4
            closeStackView.isHidden = false
            nameBackgroundView.isHidden = true
        } else {
            // Normal digital human - show avatar
            avatarImageView.backgroundColor = UIColor.clear
            closeStackView.isHidden = true
            if let url = URL(string: digitalHuman.avatar.avatarUrl) {
                avatarImageView.af.setImage(withURL: url)
            } else {
                avatarImageView.image = nil
            }
            nameBackgroundView.isHidden = false
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
            if digitalHuman.avatar.avatarId == "close" {
                disabledIconView.image = UIImage.ag_named("ic_digital_human_close_s")
                closeTitle.textColor = UIColor.themColor(named: "ai_brand_main6")
            }
        } else {
            // Unselected state
            disabledIconView.image = UIImage.ag_named("ic_digital_human_close")
            closeTitle.textColor = UIColor.themColor(named: "ai_icontext1")
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
