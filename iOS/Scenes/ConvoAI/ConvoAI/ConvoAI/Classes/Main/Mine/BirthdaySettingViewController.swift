//
//  BirthdaySettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/3.
//

import UIKit
import Common
import SnapKit

class BirthdaySettingViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.birthdaySelectTitle
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        // Maximum date: 18 years ago from today (user must be at least 18 years old)
        picker.maximumDate = Calendar.current.date(byAdding: .year, value: -18, to: Date())
        // Minimum date: 150 years ago
        picker.minimumDate = Calendar.current.date(byAdding: .year, value: -150, to: Date())
        return picker
    }()
    
    private lazy var buttonsContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.birthdayCancel, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_btn2")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.Mine.birthdayConfirm, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    private var selectedBirthday: Date = Date()
    private var completion: ((Date?) -> Void)?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        
        // Ensure selected birthday is within valid range (user must be at least 18 years old)
        if let maxDate = datePicker.maximumDate, selectedBirthday > maxDate {
            selectedBirthday = maxDate
        }
        
        datePicker.setDate(selectedBirthday, animated: false)
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
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top).offset(50)
        }
        
        buttonsContainer.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
        
        datePicker.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(buttonsContainer.snp.top).offset(-30)
            make.height.lessThanOrEqualTo(220)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(40)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(datePicker.snp.top).offset(-20)
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
    
    // MARK: - Public Methods
    static func show(in viewController: UIViewController, currentBirthday: Date, completion: @escaping (Date?) -> Void) {
        let birthdayVC = BirthdaySettingViewController()
        birthdayVC.selectedBirthday = currentBirthday
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
        dismissWithAnimation(confirmed: true)
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
