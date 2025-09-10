//
//  GenderSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

// MARK: - Gender Enum
enum Gender: String, CaseIterable {
    case female = "female"
    case male = "male"
    
    var localizedTitle: String {
        switch self {
        case .female:
            return ResourceManager.L10n.Mine.genderFemale
        case .male:
            return ResourceManager.L10n.Mine.genderMale
        }
    }
    
    var gradientColors: [UIColor] {
        switch self {
        case .female:
            return [GenderColors.femaleGradientStart, GenderColors.femaleGradientEnd]
        case .male:
            return [GenderColors.maleGradientStart, GenderColors.maleGradientEnd]
        }
    }
    
    static var defaultValue: Gender {
        return .female
    }
}

// MARK: - Gender Colors
struct GenderColors {
    // Female gradient colors
    static let femaleGradientStart = UIColor(red: 0.8, green: 1.0, blue: 0.8, alpha: 1.0)
    static let femaleGradientEnd = UIColor(red: 1.0, green: 0.99, blue: 0.59, alpha: 1.0)
    
    // Male gradient colors
    static let maleGradientStart = UIColor(red: 0.51, green: 0.82, blue: 1.0, alpha: 1.0)
    static let maleGradientEnd = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
    
    // Common colors
    static let selectionBorder = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0)
    static let confirmButton = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0)
}

class GenderSettingViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var genderOptionViews: [Gender: GenderOptionView] = {
        var views: [Gender: GenderOptionView] = [:]
        
        for gender in Gender.allCases {
            let view = GenderOptionView()
            view.configure(
                title: gender.localizedTitle,
                isSelected: gender == .defaultValue,
                gradientColors: gender.gradientColors
            )
            // Use individual methods for now
            if gender == .female {
                view.addTarget(self, action: #selector(femaleOptionSelected), for: .touchUpInside)
            } else {
                view.addTarget(self, action: #selector(maleOptionSelected), for: .touchUpInside)
            }
            views[gender] = view
        }
        
        return views
    }()
    
    private var femaleOptionView: GenderOptionView {
        return genderOptionViews[.female]!
    }
    
    private var maleOptionView: GenderOptionView {
        return genderOptionViews[.male]!
    }
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.genderConfirm, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = GenderColors.confirmButton
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var selectedGender: Gender = .defaultValue
    private let toolBox = ToolBoxApiManager()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCurrentGender()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        naviBar.title = ResourceManager.L10n.Mine.genderTitle
        
        view.addSubview(femaleOptionView)
        view.addSubview(maleOptionView)
        view.addSubview(confirmButton)
    }
    
    private func setupConstraints() {
        femaleOptionView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(naviBar.snp.bottom).offset(8)
            make.width.height.equalTo(185)
        }
        
        maleOptionView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(femaleOptionView.snp.bottom).offset(67)
            make.width.height.equalTo(185)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
    }
    
    private func loadCurrentGender() {
        // Load current gender setting from UserCenter
        if let user = UserCenter.user, !user.gender.isEmpty {
            selectedGender = Gender(rawValue: user.gender) ?? .defaultValue
        } else {
            selectedGender = .defaultValue
        }
        updateSelection()
    }
    
    private func updateSelection() {
        femaleOptionView.setSelected(selectedGender == .female)
        maleOptionView.setSelected(selectedGender == .male)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func genderOptionSelected(_ sender: UIButton) {
        // Find the gender based on the button's tag
        for (gender, view) in genderOptionViews {
            if view.tapButton == sender {
                selectedGender = gender
                updateSelection()
                break
            }
        }
    }
    
    // Keep individual methods for backward compatibility
    @objc private func femaleOptionSelected() {
        selectedGender = .female
        updateSelection()
    }
    
    @objc private func maleOptionSelected() {
        selectedGender = .male
        updateSelection()
    }
    
    @objc private func confirmButtonTapped() {
        // Save gender setting
        saveGenderSetting()
    }
    
    private func saveGenderSetting() {
        guard let user = UserCenter.user else { return }
        SVProgressHUD.show()
        toolBox.updateUserInfo(
            nickname: user.nickname,
            gender: selectedGender.rawValue,
            birthday: user.birthday,
            bio: user.bio,
            success: { [weak self] response in
                SVProgressHUD.dismiss()
                // Update local user info
                user.gender = self?.selectedGender.rawValue ?? Gender.defaultValue.rawValue
                AppContext.loginManager()?.updateUserInfo(userInfo: user)
                self?.navigationController?.popViewController(animated: true)
            },
            failure: { error in
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error)
            }
        )
    }
}

// MARK: - GenderOptionView
class GenderOptionView: UIView {
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 92.5
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 92.5
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var titleContentView: UIView = {
        let view = UIView()
        view.backgroundColor = GenderColors.selectionBorder
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var selectionBorder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderWidth = 5
        view.layer.borderColor = GenderColors.selectionBorder.cgColor
        view.layer.cornerRadius = 100
        view.isHidden = true
        return view
    }()
    
    lazy var tapButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        return button
    }()
    
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(containerView)
        addSubview(selectionBorder)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(titleContentView)
        titleContentView.addSubview(titleLabel)
        addSubview(tapButton)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        selectionBorder.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(-7.5)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        titleContentView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(24)
            make.bottom.equalTo(-9)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        }
        
        tapButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func configure(title: String, isSelected: Bool, gradientColors: [UIColor]) {
        titleLabel.text = title
        
        // Apply gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = containerView.bounds
        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        
        // Set placeholder avatar image
        avatarImageView.image = UIImage.ag_named("ic_default_avatar_icon")
        
        setSelected(isSelected)
    }
    
    func setSelected(_ selected: Bool) {
        selectionBorder.isHidden = !selected
        titleContentView.isHidden = !selected
    }
    
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        tapButton.addTarget(target, action: action, for: controlEvents)
    }
}
