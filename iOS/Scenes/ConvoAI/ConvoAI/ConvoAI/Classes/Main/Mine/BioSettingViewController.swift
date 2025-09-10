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
        view.backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.30, alpha: 1.0) // #3E3E4D
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
    
    private lazy var examplesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    // MARK: - Properties
    private let maxCharacterCount = 500
    private var originalBio: String = ""
    
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
        view.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0) // #292A2D
        
        // Configure navigation bar
        naviBar.title = "自我介绍"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(bioInputContainerView)
        bioInputContainerView.addSubview(bioTextView)
        
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
        
        examplesStackView.snp.makeConstraints { make in
            make.top.equalTo(bioInputContainerView.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func setupExampleCards() {
        let examples = [
            "我宅家养多肉、学做菜，细心又爱帮朋友。妈妈做的番茄炒蛋是本命，夏天的冰镇荔枝，清甜劲儿超治愈～",
            "互联网运营 er 一枚，日常跟数据、文案死磕，擅长抓热点做内容。闲了爱撸代码解压，奶茶续命党，生椰拿铁是本命，求搭子聊运营干货～",
            "前端开发仔报道，沉迷调样式、优化交互，追新技术像追更。爱喝冰美式提效，周末宅家肝游戏，求技术搭子交流 bug 解决方案～",
            "产品经理一枚，天天画原型、盯迭代，擅长抠需求细节。咖啡不离手，偏爱冷萃，闲了刷行业报告，求同频小伙伴唠产品思路～"
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
        // Load current bio from UserCenter or other sources
//        if let userInfo = UserCenter.shared.getUserInfo() {
//            originalBio = userInfo.bio ?? ""
//            bioTextView.text = originalBio
//        }
    }
    
    // MARK: - Actions
    override func viewWillDisappearAndPop() {
        super.viewWillDisappearAndPop()
        if bioTextView.text != originalBio {
            showUnsavedChangesAlert()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    private func showUnsavedChangesAlert() {
        let alert = UIAlertController(
            title: "未保存的更改",
            message: "您有未保存的更改，确定要离开吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "放弃", style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "继续编辑", style: .cancel))
        
        present(alert, animated: true)
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
