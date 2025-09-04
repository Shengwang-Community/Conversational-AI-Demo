//
//  GenderSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class GenderSettingViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.genderSettingTitle
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var femaleOptionView: GenderOptionView = {
        let view = GenderOptionView()
        view.configure(
            icon: "ic_female_avatar_icon",
            title: ResourceManager.L10n.Mine.genderFemale,
            isSelected: true,
            gradientColors: [UIColor.themColor(named: "ai_gradient_green"), UIColor.themColor(named: "ai_gradient_yellow")]
        )
        view.addTarget(self, action: #selector(femaleOptionSelected), for: .touchUpInside)
        return view
    }()
    
    private lazy var maleOptionView: GenderOptionView = {
        let view = GenderOptionView()
        view.configure(
            icon: "ic_male_avatar_icon",
            title: ResourceManager.L10n.Mine.genderMale,
            isSelected: false,
            gradientColors: [UIColor.themColor(named: "ai_gradient_blue"), UIColor.themColor(named: "ai_gradient_purple")]
        )
        view.addTarget(self, action: #selector(maleOptionSelected), for: .touchUpInside)
        return view
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
//        button.setTitle(ResourceManager.L10n.Mine.confirm, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var selectedGender: Gender = .female
    
    enum Gender {
        case female
        case male
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCurrentGender()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        view.addSubview(femaleOptionView)
        view.addSubview(maleOptionView)
        view.addSubview(confirmButton)
    }
    
    private func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(60)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        femaleOptionView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(200)
        }
        
        maleOptionView.snp.makeConstraints { make in
            make.top.equalTo(femaleOptionView.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(200)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
    }
    
    private func loadCurrentGender() {
        // Load current gender setting from UserCenter or other sources
        // For now, default to female
        selectedGender = .female
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
        
        // Show success message
        SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.Mine.genderSettingSaved)
        
        // Pop back to previous view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func saveGenderSetting() {
        // Save gender setting to UserCenter or other storage
//        UserCenter.shared.setGender(selectedGender == .female ? "female" : "male")
    }
}

// MARK: - GenderOptionView
class GenderOptionView: UIView {
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 100
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var titleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 12
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var selectionBorder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
        view.layer.cornerRadius = 103
        view.isHidden = true
        return view
    }()
    
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
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleButton)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        selectionBorder.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(-3)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(120)
        }
        
        titleButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.width.equalTo(60)
            make.height.equalTo(24)
        }
    }
    
    func configure(icon: String, title: String, isSelected: Bool, gradientColors: [UIColor]) {
        iconImageView.image = UIImage.ag_named(icon)
        titleButton.setTitle(title, for: .normal)
        
        // Apply gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = containerView.bounds
        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        
        setSelected(isSelected)
    }
    
    func setSelected(_ selected: Bool) {
        selectionBorder.isHidden = !selected
    }
    
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        let tapGesture = UITapGestureRecognizer(target: target, action: action)
        addGestureRecognizer(tapGesture)
    }
}
