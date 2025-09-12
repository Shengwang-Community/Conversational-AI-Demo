//
//  BioSettingViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SnapKit
import SVProgressHUD

class BioSettingViewController: BaseViewController {
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var bioInputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 16
        return view
    }()
    
    private lazy var bioTextView: UITextView = {
        let textView = UITextView()
        textView.textColor = .white
        textView.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        textView.delegate = self
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Mine.bioInputPlaceholder
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var examplesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    // MARK: - Properties
    private let maxCharacterCount = 500
    private var originalBio: String = ""
    private let toolBox = ToolBoxApiManager()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCurrentBio()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bioTextView.becomeFirstResponder()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        
        // Configure navigation bar
        naviBar.title = ResourceManager.L10n.Mine.bioSettingTitle
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(bioInputContainerView)
        bioInputContainerView.addSubview(bioTextView)
        bioInputContainerView.addSubview(placeholderLabel)
        
        contentView.addSubview(examplesStackView)
        
        // Add example bio cards
        setupExampleCards()
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        bioInputContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(250)
        }
        
        bioTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        placeholderLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.left.equalToSuperview().offset(22)
            make.right.equalToSuperview().offset(-18)
        }
        
        examplesStackView.snp.makeConstraints { make in
            make.top.equalTo(bioInputContainerView.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func setupExampleCards() {
        let examples = [
            ResourceManager.L10n.Mine.bioExample1,
            ResourceManager.L10n.Mine.bioExample2,
            ResourceManager.L10n.Mine.bioExample3,
            ResourceManager.L10n.Mine.bioExample4
        ]
        
        for example in examples {
            let card = BioExampleCard()
            card.configure(text: example)
            card.onTap = { [weak self] in
                self?.bioTextView.text = card.text
            }
            examplesStackView.addArrangedSubview(card)
        }
    }
    
    private func loadCurrentBio() {
        // Load current bio from UserCenter
        if let user = UserCenter.user {
            originalBio = user.bio
            bioTextView.text = originalBio
            updatePlaceholderVisibility()
        }
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !bioTextView.text.isEmpty
    }
    
    // MARK: - Actions
    
    @objc private func dismissKeyboard() {
        saveBioIfChanged()
        view.endEditing(true)
    }
    
    private func saveBio(_ bio: String) {
        guard let user = UserCenter.user else { return }
        user.bio = bio
        SVProgressHUD.show()
        toolBox.updateUserInfo(
            nickname: user.nickname,
            gender: user.gender,
            birthday: user.birthday,
            bio: user.bio,
            success: { [weak self] response in
                SVProgressHUD.dismiss()
                self?.originalBio = bio
                AppContext.loginManager().updateUserInfo(userInfo: user)
            },
            failure: { error in
                SVProgressHUD.dismiss()
            }
        )
    }
    
    private func saveBioIfChanged() {
        let newBio = bioTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if newBio.count > maxCharacterCount {
            // Truncate bio to maxCharacterCount and continue
            let truncatedBio = String(newBio.prefix(maxCharacterCount))
            bioTextView.text = truncatedBio
        }
        
        if newBio != originalBio {
            saveBio(newBio)
        }
    }
}

// MARK: - UITextViewDelegate
extension BioSettingViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: text)
        
        // Check if new text exceeds character limit
        if newText.count > maxCharacterCount {
            return false
        }
        
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
    }
}

// MARK: - BioExampleCard
class BioExampleCard: UIView {
    
    // MARK: - UI Components
    private lazy var arrowIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_mine_bio_arrow")
        imageView.tintColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var tapButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        button.setBackgroundColor(color: UIColor.themColor(named: "ai_click_app"), forState: .highlighted)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return button
    }()
    
    // MARK: - Properties
    var text: String = ""
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        addSubview(tapButton)
        addSubview(arrowIcon)
        addSubview(textLabel)
        
        arrowIcon.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.top.equalToSuperview().offset(8)
            make.width.height.equalTo(20)
        }
        
        textLabel.snp.makeConstraints { make in
            make.left.equalTo(arrowIcon.snp.right).offset(6)
            make.right.equalToSuperview().offset(-10)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
        
        tapButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Configuration
    func configure(text: String) {
        self.text = text
        textLabel.text = text
    }
    
    // MARK: - Actions
    @objc private func buttonTapped() {
        onTap?()
    }
}
