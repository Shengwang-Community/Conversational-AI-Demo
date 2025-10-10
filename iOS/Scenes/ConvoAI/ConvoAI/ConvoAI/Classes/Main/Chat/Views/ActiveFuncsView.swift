//
//  ActiveFuncsView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit

class ActiveFuncsView: UIView {
    
    var onMoreTapped: (() -> Void)?
    
    // Store references to the items for state updates
    private lazy var lockOption: ActiveFuncItemView = {
        let view = ActiveFuncItemView()
        view.configure(icon: "ic_funcs_state_off", text: ResourceManager.L10n.ChannelInfo.voiceprintLock)
        return view
    }()
    
    private lazy var interruptOption: ActiveFuncItemView = {
        let view = ActiveFuncItemView()
        view.configure(icon: "ic_funcs_state_off", text: ResourceManager.L10n.ChannelInfo.elegantInterrupt)
        return view
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block1")
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var optionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 0
        return stackView
    }()
    
    private lazy var collapseButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_triangle_down"), for: .normal)
        button.setImage(UIImage.ag_named("ic_triangle_up"), for: .selected)
        button.tintColor = .white
        button.addTarget(self, action: #selector(onCollapseTapped), for: .touchUpInside)
        button.isSelected = false
        return button
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
    
    func setState(voiceprint: Bool, aivad: Bool) {
        // Update voiceprint lock icon
        let voiceprintIcon = voiceprint ? "ic_funcs_state_on" : "ic_funcs_state_off"
        lockOption.configure(icon: voiceprintIcon, text: ResourceManager.L10n.ChannelInfo.voiceprintLock)
        
        // Update elegant interrupt icon
        let aivadIcon = aivad ? "ic_funcs_state_on" : "ic_funcs_state_off"
        interruptOption.configure(icon: aivadIcon, text: ResourceManager.L10n.ChannelInfo.elegantInterrupt)
    }
    
    func resetState() {
        setState(voiceprint: false, aivad: false)
        onCollapseTapped()
    }
    
    func setButtonColorTheme(showLight: Bool) {
        backgroundColor = showLight ? UIColor.themColor(named: "ai_brand_black4") : UIColor.themColor(named: "ai_block1")
    }
    
    // MARK: - UI Setup
    
    private func setupViews() {
        self.backgroundColor = UIColor.themColor(named: "ai_block1")
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true

        addSubview(contentView)
        contentView.addSubview(optionsStackView)
        
        // Set up constraints for items
        lockOption.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        interruptOption.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        // Create more button
        let moreButton = UIButton(type: .custom)
        moreButton.setTitle(ResourceManager.L10n.ChannelInfo.more, for: .normal)
        moreButton.setTitleColor(.white, for: .normal)
        moreButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .regular)
        moreButton.addTarget(self, action: #selector(onMoreTappedAction), for: .touchUpInside)
        moreButton.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        // Add items to stack view
        optionsStackView.addArrangedSubview(lockOption)
        optionsStackView.addArrangedSubview(interruptOption)
        optionsStackView.addArrangedSubview(moreButton)
        
        // Add collapse button
        addSubview(collapseButton)
    }
    
    private func setupConstraints() {
        contentView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(24)
        }
        
        optionsStackView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(24 * 3) // 3 items * 24pt
        }
        
        collapseButton.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(20)
            make.bottom.equalToSuperview()
        }
        
        // Set priority to ensure constraint stability during animation
        contentView.setContentHuggingPriority(.required, for: .vertical)
        contentView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    
    // MARK: - Actions
    
    @objc private func onCollapseTapped() { 
        collapseButton.isSelected.toggle()

        // Use more stable animation method
        if collapseButton.isSelected {
            // Expand animation
            expandContent()
        } else {
            // Collapse animation
            collapseContent()
        }
    }
    
    private func expandContent() {
        // First set height constraint
        contentView.snp.updateConstraints { make in
            make.height.equalTo(24 * 3 + 8) // 3 items * 24pt
        }
        
        // Use spring animation
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.superview?.layoutIfNeeded()
        }
    }
    
    private func collapseContent() {
        // When collapsed, show first row view (height 24)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.contentView.snp.updateConstraints { make in
                make.height.equalTo(24)
            }
            self.superview?.layoutIfNeeded()
        }
    }
    
    @objc private func onMoreTappedAction() {
        onMoreTapped?()
    }
}

// MARK: - ActiveFuncItemView Component
class ActiveFuncItemView: UIView {
    
    // MARK: - UI Components
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .white
        return label
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
        backgroundColor = .clear
        
        addSubview(iconImageView)
        addSubview(titleLabel)
    }
    
    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(4)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview().offset(-8)
        }
    }
    
    // MARK: - Configuration
    func configure(icon: String, text: String) {
        iconImageView.image = UIImage.ag_named(icon)
        titleLabel.text = text
    }
    
}


