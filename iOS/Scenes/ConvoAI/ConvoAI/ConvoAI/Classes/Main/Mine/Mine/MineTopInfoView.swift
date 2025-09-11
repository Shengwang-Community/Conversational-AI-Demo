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
    
    weak var delegate: MineTopInfoViewDelegate?
        
    private lazy var imageView1: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_top_bg")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var imageView2: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_gender_holder")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var titleCycleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_title_cycle")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_default_avatar_icon")
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.layer.borderWidth = 1
        return imageView
    }()
    
    // Profile Info Button (combines name and arrow)
    private lazy var profileInfoButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: ResourceManager.L10n.Mine.personaTitle)
        button.tapButton.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var backBoardImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_mine_back_board")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var bigAvatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 30
        imageView.layer.masksToBounds = true
        return imageView
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
        label.text = ResourceManager.L10n.Mine.personaTitle
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return label
    }()
    
    private lazy var addressingButton: MineInfoButton = {
        let button = MineInfoButton()
        button.configure(title: ResourceManager.L10n.Mine.addressingTitle)
        button.tapButton.addTarget(self, action: #selector(addressingButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var addressingLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.addressingTitle
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var birthdayLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.birthdayTitle
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var birthdayValueButton: MineInfoButton = {
        let button = MineInfoButton()
        button.tapButton.addTarget(self, action: #selector(birthdayButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var bioLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.bioTitle
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var bioValueButton: MineInfoButton = {
        let button = MineInfoButton()
        button.tapButton.addTarget(self, action: #selector(bioButtonTapped), for: .touchUpInside)
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
        
        addSubview(imageView1)
        addSubview(backBoardImageView)
        addSubview(bigAvatarImageView)
        addSubview(imageView2)
        addSubview(avatarImageView)
        addSubview(profileInfoButton)
        
        // Persona Card
        addSubview(personaCardView)
        personaCardView.addSubview(personaCardBGView)
        personaCardView.addSubview(cardTitleLabel)
        personaCardView.addSubview(titleCycleImageView)
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
        imageView1.snp.makeConstraints { make in
            make.top.right.equalToSuperview()
        }
        
        backBoardImageView.snp.makeConstraints { make in
            make.top.equalTo(personaCardView).offset(-6)
            make.right.equalTo(personaCardView).offset(16)
        }
        
        bigAvatarImageView.snp.makeConstraints { make in
            make.top.equalTo(personaCardView).offset(-76)
            make.right.equalToSuperview()
        }
        imageView2.snp.makeConstraints { make in
            make.top.equalTo(personaCardView).offset(-5)
            make.right.equalTo(personaCardView)
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
        
        titleCycleImageView.snp.makeConstraints { make in
            make.top.equalTo(cardTitleLabel)
            make.right.equalTo(cardTitleLabel)
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
            make.right.lessThanOrEqualToSuperview().offset(-20)
            make.height.equalTo(20)
        }

        bottomMaskView.snp.makeConstraints { make in
            make.top.equalTo(personaCardView.snp.bottom).offset(-28)
            make.left.right.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func updateUserInfo(nickname: String, birthday: String, bio: String, gender: String) {
        profileInfoButton.configure(title: nickname)
        birthdayValueButton.configure(title: birthday.isEmpty ? ResourceManager.L10n.Mine.placeholderSelect : birthday)
        bioValueButton.configure(title: bio.isEmpty ? ResourceManager.L10n.Mine.bioPlaceholderDisplay : bio)
        updateAddressingAndAvatarsBasedOnGender(gender)
    }
    
    private func updateAddressingAndAvatarsBasedOnGender(_ gender: String) {
        if gender == "female" {
            addressingButton.configure(title: ResourceManager.L10n.Mine.genderFemale)
            avatarImageView.image = UIImage.ag_named("img_mine_avatar_female")
            avatarImageView.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
            imageView2.isHidden = true
            bigAvatarImageView.isHidden = false
            bigAvatarImageView.image = UIImage.ag_named("img_mine_gender_female_big")
        } else if gender == "male" {
            addressingButton.configure(title: ResourceManager.L10n.Mine.genderMale)
            avatarImageView.image = UIImage.ag_named("img_mine_avatar_male")
            avatarImageView.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
            imageView2.isHidden = true
            bigAvatarImageView.isHidden = false
            bigAvatarImageView.image = UIImage.ag_named("img_mine_gender_male_big")
        } else {
            addressingButton.configure(title: ResourceManager.L10n.Mine.placeholderSelect)
            avatarImageView.image = UIImage.ag_named("img_mine_avatar_holder")
            avatarImageView.layer.borderColor = UIColor.clear.cgColor
            imageView2.isHidden = false
            bigAvatarImageView.isHidden = true
            bigAvatarImageView.image = UIImage.ag_named("img_mine_gender_female_big")
        }
    }
    
    // MARK: - Actions
    @objc private func profileButtonTapped() {
        delegate?.mineTopInfoViewDidTapProfile()
    }
    
    @objc private func addressingButtonTapped() {
        delegate?.mineTopInfoViewDidTapAddressing()
    }
    
    @objc private func birthdayButtonTapped() {
        delegate?.mineTopInfoViewDidTapBirthday()
    }
    
    @objc private func bioButtonTapped() {
        delegate?.mineTopInfoViewDidTapBio()
    }
}

// MARK: - MineInfoButton Component
class MineInfoButton: UIView {
    
    // MARK: - UI Components
    let titleLabel: UILabel = {
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
    
    let tapButton: UIButton = {
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
    
    // MARK: - Configuration
    func configure(title: String) {
        titleLabel.text = title
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
