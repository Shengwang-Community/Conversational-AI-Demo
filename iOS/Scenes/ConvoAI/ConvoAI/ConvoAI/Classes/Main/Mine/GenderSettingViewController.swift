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

class GenderSettingViewController: BaseViewController {
    
    // MARK: - UI Components
    
    private lazy var femaleOptionView: GenderOptionView = {
        let view = GenderOptionView()
        view.configure(
            title: "女士",
            isSelected: true,
            gradientColors: [UIColor(red: 0.8, green: 1.0, blue: 0.8, alpha: 1.0), UIColor(red: 1.0, green: 0.99, blue: 0.59, alpha: 1.0)]
        )
        view.addTarget(self, action: #selector(femaleOptionSelected), for: .touchUpInside)
        return view
    }()
    
    private lazy var maleOptionView: GenderOptionView = {
        let view = GenderOptionView()
        view.configure(
            title: "男士",
            isSelected: false,
            gradientColors: [UIColor(red: 0.51, green: 0.82, blue: 1.0, alpha: 1.0), UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)]
        )
        view.addTarget(self, action: #selector(maleOptionSelected), for: .touchUpInside)
        return view
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("确定", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0) // #446CFF
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.layer.cornerRadius = 12
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
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        naviBar.title = "称呼您为"
        
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
        SVProgressHUD.showSuccess(withStatus: "性别设置已保存")
        
        // Pop back to previous view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func saveGenderSetting() {
        // Save gender setting to UserCenter or other storage
        // UserCenter.shared.setGender(selectedGender == .female ? "female" : "male")
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
        view.backgroundColor = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0)
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
        view.layer.borderColor = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0).cgColor
        view.layer.cornerRadius = 100
        view.isHidden = true
        return view
    }()
    
    private lazy var tapButton: UIButton = {
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
