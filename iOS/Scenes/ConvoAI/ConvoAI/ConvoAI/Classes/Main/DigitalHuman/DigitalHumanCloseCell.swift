//
//  DigitalHumanCloseCell.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/16.
//

import UIKit
import Common

class DigitalHumanCloseCell: UICollectionViewCell {
    static let identifier = "DigitalHumanCloseCell"
    
    // MARK: - UI Components
    private lazy var containerButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.systemGray4
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        return button
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
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    private lazy var selectionIndicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_digital_human_circle")
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        return imageView
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
        containerButton.addSubview(closeStackView)
        containerButton.addSubview(selectionIndicatorView)
    }
    
    private func setupConstraints() {
        containerButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        disabledIconView.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
        
        selectionIndicatorView.snp.makeConstraints { make in
            make.bottom.equalTo(-6)
            make.right.equalTo(-8)
            make.width.height.equalTo(24)
        }
    }
    
    private func setupActions() {
        containerButton.addTarget(self, action: #selector(onSelectionTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with digitalHuman: DigitalHuman) {
        self.digitalHuman = digitalHuman
        updateSelectionState()
    }
    
    private func updateSelectionState() {
        guard let digitalHuman = digitalHuman else { return }
        
        if digitalHuman.isSelected {
            // Selected state
            containerButton.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
            disabledIconView.image = UIImage.ag_named("ic_digital_human_close_s")
            closeTitle.textColor = UIColor.themColor(named: "ai_brand_main6")
            selectionIndicatorView.image = UIImage.ag_named("ic_digital_human_circle_s")
        } else {
            // Unselected state
            containerButton.layer.borderColor = UIColor.clear.cgColor
            disabledIconView.image = UIImage.ag_named("ic_digital_human_close")
            closeTitle.textColor = UIColor.themColor(named: "ai_icontext1")
            selectionIndicatorView.image = UIImage.ag_named("ic_digital_human_circle")
        }
    }
    
    // MARK: - Actions
    @objc private func onSelectionTapped() {
        guard let digitalHuman = digitalHuman else { return }
        onSelectionChanged?(digitalHuman)
    }
}
