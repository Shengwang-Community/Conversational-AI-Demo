//
//  BirthdaySettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class BirthdaySettingViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0) // #292A2D
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "选择您的生日"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.backgroundColor = .clear
        picker.maximumDate = Date()
        picker.minimumDate = Calendar.current.date(byAdding: .year, value: -100, to: Date())
        return picker
    }()
    
    private lazy var buttonsContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("确定", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.27, green: 0.42, blue: 1.0, alpha: 1.0) // #446CFF
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var originalBirthday: Date?
    private var selectedBirthday: Date = Date()
    private var completion: ((Date?) -> Void)?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCurrentBirthday()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(backgroundView)
        view.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(datePicker)
        containerView.addSubview(buttonsContainer)
        
        buttonsContainer.addSubview(cancelButton)
        buttonsContainer.addSubview(confirmButton)
        
        // Add tap gesture to background
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(400)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        datePicker.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(200)
        }
        
        buttonsContainer.snp.makeConstraints { make in
            make.top.equalTo(datePicker.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(confirmButton)
            make.height.equalTo(50)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.left.equalTo(cancelButton.snp.right).offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(50)
        }
    }
    
    private func loadCurrentBirthday() {
        // Load current birthday from UserCenter or other sources
        // For now, set a default date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        if let date = formatter.date(from: "1998/02/02") {
            originalBirthday = date
            selectedBirthday = date
            datePicker.date = date
        }
    }
    
    // MARK: - Public Methods
    static func show(in viewController: UIViewController, currentBirthday: Date? = nil, completion: @escaping (Date?) -> Void) {
        let birthdayVC = BirthdaySettingViewController()
        birthdayVC.originalBirthday = currentBirthday
        birthdayVC.selectedBirthday = currentBirthday ?? Date()
        birthdayVC.completion = completion
        
        birthdayVC.modalPresentationStyle = .overFullScreen
        viewController.present(birthdayVC, animated: false)
    }
    
    // MARK: - Actions
    @objc private func backgroundTapped() {
        dismissWithAnimation()
    }
    
    @objc private func cancelButtonTapped() {
        dismissWithAnimation()
    }
    
    @objc private func confirmButtonTapped() {
        selectedBirthday = datePicker.date
        saveBirthday(selectedBirthday)
    }
    
    private func saveBirthday(_ birthday: Date) {
        // Show loading
        SVProgressHUD.show(withStatus: "保存中...")
        
        // Simulate save process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SVProgressHUD.dismiss()
            
            // Save to UserCenter
            // UserCenter.shared.setBirthday(birthday)
            
            // Update original birthday
            self.originalBirthday = birthday
            
            // Show success message
            SVProgressHUD.showSuccess(withStatus: "生日保存成功")
            
            // Dismiss with completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.dismissWithAnimation(confirmed: true)
            }
        }
    }
    
    private func animateIn() {
        containerView.transform = CGAffineTransform(translationX: 0, y: 400)
        backgroundView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.backgroundView.alpha = 1
        }
    }
    
    private func dismissWithAnimation(confirmed: Bool = false) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: 400)
            self.backgroundView.alpha = 0
        }) { _ in
            self.dismiss(animated: false) {
                if confirmed {
                    self.completion?(self.selectedBirthday)
                } else {
                    self.completion?(nil)
                }
            }
        }
    }
}
