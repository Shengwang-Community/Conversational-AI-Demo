//
//  MineTopInfoView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit

// MARK: - MineTopInfoViewDelegate
protocol MineTopInfoViewDelegate: AnyObject {
    func mineTopInfoViewDidTapProfile()
    func mineTopInfoViewDidTapAddressing()
    func mineTopInfoViewDidTapBirthday()
    func mineTopInfoViewDidTapBio()
}

class MineTopInfoView: UIView {
    
    // MARK: - Properties
    weak var delegate: MineTopInfoViewDelegate?
    
    // MARK: - UI Components
    
    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_background")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_default_avatar_icon")
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
        return imageView
    }()
    
    // Profile Info Button (combines name and arrow)
    private lazy var profileInfoButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: "尹希尔") {
            self.delegate?.mineTopInfoViewDidTapProfile()
        }
        return button
    }()
    
    // Conversation Persona Card
    private lazy var personaCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var personaCardBGView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_info_card")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var cardTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "我的对话人设"
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private lazy var addressingButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: "先生") {
            self.delegate?.mineTopInfoViewDidTapAddressing()
        }
        return button
    }()
    
    private lazy var addressingLabel: UILabel = {
        let label = UILabel()
        label.text = "称呼您为"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var birthdayLabel: UILabel = {
        let label = UILabel()
        label.text = "您的生日"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var birthdayValueButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: "1998/02/02") {
            self.delegate?.mineTopInfoViewDidTapBirthday()
        }
        return button
    }()
    

    
    private lazy var bioLabel: UILabel = {
        let label = UILabel()
        label.text = "自我介绍"
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var bioValueButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: "sdksdhjksdjssdhsxcsdksdhjksdjssdhsxcx...") {
            self.delegate?.mineTopInfoViewDidTapBio()
        }
        return button
    }()

    private lazy var bottomMaskView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_info_bg_mask")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
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
        clipsToBounds = true
        
        addSubview(backgroundImageView)
        addSubview(avatarImageView)
        addSubview(profileInfoButton)
        
        // Persona Card
        addSubview(personaCardView)
        personaCardView.addSubview(personaCardBGView)
        personaCardView.addSubview(cardTitleLabel)
        personaCardView.addSubview(addressingButton)
        personaCardView.addSubview(addressingLabel)
        personaCardView.addSubview(birthdayLabel)
        personaCardView.addSubview(birthdayValueButton)
        personaCardView.addSubview(bioLabel)
        personaCardView.addSubview(bioValueButton)

        addSubview(bottomMaskView)
    }
    
    private func setupConstraints() {
        // Header constraints
        
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(40)
            make.top.equalToSuperview().offset(40)
            make.width.height.equalTo(40)
        }
        
        profileInfoButton.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(16)
            make.centerY.equalTo(avatarImageView)
            make.height.equalTo(60)
        }
        
        // Persona Card constraints
        personaCardView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(54)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(195)
        }
        
        personaCardBGView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        cardTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.left.equalTo(17)
        }
        
        addressingLabel.snp.makeConstraints { make in
            make.top.equalTo(cardTitleLabel.snp.bottom).offset(25)
            make.left.equalToSuperview().offset(20)
        }
        
        addressingButton.snp.makeConstraints { make in
            make.top.equalTo(addressingLabel.snp.bottom).offset(8)
            make.left.equalTo(addressingLabel)
            make.height.equalTo(20)
        }
        
        birthdayLabel.snp.makeConstraints { make in
            make.top.equalTo(addressingLabel.snp.top)
            make.right.equalToSuperview().offset(-80)
        }
        
        birthdayValueButton.snp.makeConstraints { make in
            make.top.equalTo(birthdayLabel.snp.bottom).offset(8)
            make.left.equalTo(birthdayLabel)
            make.height.equalTo(20)
        }
        
        bioLabel.snp.makeConstraints { make in
            make.top.equalTo(addressingButton.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(20)
        }
        
        bioValueButton.snp.makeConstraints { make in
            make.top.equalTo(bioLabel.snp.bottom).offset(8)
            make.left.equalTo(bioLabel)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(20)
        }

        bottomMaskView.snp.makeConstraints { make in
            make.top.equalTo(personaCardView.snp.bottom).offset(-28)
            make.left.right.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func updateUserInfo(nickname: String?, birthday: String?, bio: String?) {
        if let nickname = nickname {
            profileInfoButton.configure(title: nickname) {
                self.delegate?.mineTopInfoViewDidTapProfile()
            }
        }
        
        if let birthday = birthday {
            birthdayValueButton.configure(title: birthday) {
                self.delegate?.mineTopInfoViewDidTapBirthday()
            }
        }
        
        if let bio = bio {
            bioValueButton.configure(title: bio) {
                self.delegate?.mineTopInfoViewDidTapBio()
            }
        }
    }
    
    func updateAddressing(_ addressing: String) {
        addressingButton.configure(title: addressing) {
            self.delegate?.mineTopInfoViewDidTapAddressing()
        }
    }
}

// MARK: - MineInfoButton Component
class MineInfoButton: UIView {
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return label
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_info_arrow")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var tapButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    var onTap: (() -> Void)?
    
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
        layer.cornerRadius = 0
        
        addSubview(titleLabel)
        addSubview(arrowImageView)
        addSubview(tapButton)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(arrowImageView.snp.left).offset(-4)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        tapButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func buttonTapped() {
        onTap?()
    }
    
    // MARK: - Configuration
    func configure(title: String, onTap: @escaping () -> Void) {
        titleLabel.text = title
        self.onTap = onTap
    }
    
    func setTitleColor(_ color: UIColor) {
        titleLabel.textColor = color
    }
    
    func setArrowColor(_ color: UIColor) {
        arrowImageView.tintColor = color
        // For custom images, we need to set the rendering mode
        if let originalImage = arrowImageView.image {
            arrowImageView.image = originalImage.withRenderingMode(.alwaysTemplate)
        }
    }
    
    func setBackgroundColor(_ color: UIColor) {
        backgroundColor = color
        layer.cornerRadius = 0
    }
}
