//
//  CustomInputView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/26.
//

import UIKit
import SnapKit
import Common

class BottomInputView: UIView, UITextFieldDelegate {

    private let maxCharCount = 8

    let inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 16
        
        return view
    }()

    let textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.keyboardType = .numberPad
        textField.clearButtonMode = .whileEditing
        textField.font = .systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            .font: UIFont.systemFont(ofSize: 14)
        ]
        textField.attributedPlaceholder = NSAttributedString(string: ResourceManager.L10n.AgentList.input, attributes: attributes)
        return textField
    }()

    let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(ResourceManager.L10n.AgentList.fetch, for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.layer.cornerRadius = 10
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        textField.delegate = self
        backgroundColor = UIColor.themColor(named: "ai_fill1")
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(inputContainerView)
        inputContainerView.addSubview(textField)
        inputContainerView.addSubview(actionButton)

        inputContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }

        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-9)
            make.centerY.equalToSuperview()
            make.width.equalTo(78)
            make.height.equalTo(36)
        }

        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalTo(actionButton.snp.leading).offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }
        
        self.snp.makeConstraints { make in
            make.height.equalTo(74)
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        let newLength = text.count + string.count - range.length
        return newLength <= maxCharCount
    }
}

class BottomInputViewController: UIViewController {

    private let bottomInputView = BottomInputView()
        private var bottomConstraint: Constraint?
    var completion: ((Bool, String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bottomInputView.textField.becomeFirstResponder()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_mask1")
        view.addSubview(bottomInputView)

        bottomInputView.actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

        bottomInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            self.bottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).constraint
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
              let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue else { return }

        let keyboardHeight = keyboardFrame.height
        let newBottomOffset = -keyboardHeight + view.safeAreaInsets.bottom

        bottomConstraint?.update(offset: newBottomOffset)

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve), animations: {
            self.view.layoutIfNeeded()
        })
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
              let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue else { return }

        bottomConstraint?.update(offset: 0)

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve), animations: {
            self.view.layoutIfNeeded()
        })
    }

    @objc private func actionButtonTapped() {
        let text = bottomInputView.textField.text ?? ""
        self.completion?(true, text)
        self.dismiss(animated: true) {
        }
    }

    @objc private func dismissKeyboard() {
        let text = bottomInputView.textField.text ?? ""
        view.endEditing(true)
        self.completion?(false, text)
        self.dismiss(animated: true) {
        }
    }
}
