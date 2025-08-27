//  VoiceprintViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/26.
//

import UIKit
import SnapKit
import Common
import SVProgressHUD

enum VoiceprintMode: Int, CaseIterable {
    case off = 0
    case seamless = 1
    case aware = 2
    
    var title: String {
        switch self {
        case .off:
            return ResourceManager.L10n.VoiceprintMode.off
        case .seamless:
            return ResourceManager.L10n.VoiceprintMode.seamless
        case .aware:
            return ResourceManager.L10n.VoiceprintMode.aware
        }
    }
    
    var description: String {
        switch self {
        case .off:
            return ResourceManager.L10n.VoiceprintMode.offDescription
        case .seamless:
            return ResourceManager.L10n.VoiceprintMode.seamlessDescription
        case .aware:
            return ResourceManager.L10n.VoiceprintMode.awareDescription
        }
    }
}

class VoiceprintViewController: BaseViewController {
    
    private var selectedMode: VoiceprintMode = .off
    
    private lazy var groupedListView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.backgroundColor = UIColor.themColor(named: "ai_block2")
        stackView.layer.cornerRadius = 12
        stackView.layer.masksToBounds = true
        return stackView
    }()
    
    private var modeItems: [VoiceprintModeItemView] = []
        
    private lazy var voiceprintCreationTab: VoiceprintCreationTabView = {
        let view = VoiceprintCreationTabView()
        view.bindCreateButtonAction(target: self, action: #selector(onCreateVoiceprintTapped))
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer.masksToBounds = true
        return view
    }()
        
    init(selectedMode: VoiceprintMode = .off) {
        self.selectedMode = selectedMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupModeItems()
        loadCurrentVoiceprintMode()
    }
        
    private func setupViews() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.addSubview(voiceprintCreationTab)
        view.addSubview(groupedListView)
    }
    
    private func setupConstraints() {
        groupedListView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(40)
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.height.lessThanOrEqualTo(500)
        }
        voiceprintCreationTab.snp.makeConstraints { make in
            make.top.equalTo(groupedListView.snp.bottom).offset(-20)
            make.width.centerX.equalTo(groupedListView)
            make.height.equalTo(108)
        }
    }
    
    private func setupModeItems() {
        for (index, mode) in VoiceprintMode.allCases.enumerated() {
            let itemView = VoiceprintModeItemView(mode: mode, isSelected: mode == selectedMode)
            itemView.tag = index
            itemView.addTarget(self, action: #selector(modeItemTapped(_:)), for: .touchUpInside)
            
            groupedListView.addArrangedSubview(itemView)
            modeItems.append(itemView)
            
            // Add separator line except for the last item
            if index < VoiceprintMode.allCases.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor.themColor(named: "ai_line2")
                separator.snp.makeConstraints { make in
                    make.height.equalTo(0.5)
                }
                groupedListView.addArrangedSubview(separator)
            }
        }
    }
        
    func updateSelectedMode(_ mode: VoiceprintMode) {
        selectedMode = mode
        for (index, itemView) in modeItems.enumerated() {
            let isSelected = VoiceprintMode.allCases[index] == mode
            itemView.updateSelection(isSelected: isSelected)
        }
    }
    
    private func loadCurrentVoiceprintMode() {
        // TODO: Get current voiceprint mode from preference manager
        // For now, default to .off
        selectedMode = .off
        updateSelectedMode(selectedMode)
    }
        
    @objc private func onCreateVoiceprintTapped() {
        let recordViewController = VoiceprintRecordViewController()
        recordViewController.modalPresentationStyle = .overFullScreen
        recordViewController.modalTransitionStyle = .crossDissolve
        present(recordViewController, animated: true)
    }
    
    @objc private func modeItemTapped(_ sender: VoiceprintModeItemView) {
        let selectedIndex = sender.tag
        guard selectedIndex < VoiceprintMode.allCases.count else { return }
        
        let newMode = VoiceprintMode.allCases[selectedIndex]
        
        // Update selection state
        for (index, itemView) in modeItems.enumerated() {
            itemView.updateSelection(isSelected: index == selectedIndex)
        }
        
        // Update selected mode
        selectedMode = newMode
        
        // Update preference manager
//        AppContext.preferenceManager()?.updateVoiceprintMode(newMode)
        
        // Show success feedback
        SVProgressHUD.showSuccess(withStatus: ResourceManager.L10n.VoiceprintMode.settingSuccess)
    }
}

// MARK: - VoiceprintCreationTabView
class VoiceprintCreationTabView: UIView {
    
    private lazy var voiceprintIconView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 57/255, green: 202/255, blue: 255/255, alpha: 1.0) // #39CAFF
        view.layer.cornerRadius = 8
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.06
        view.layer.shadowRadius = 6
        return view
    }()
    
    private lazy var voiceprintIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_agent_mute") // 使用现有的麦克风图标
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private lazy var voiceprintTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "创建我的声纹"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        return label
    }()
    
    lazy var createButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 8
        button.setTitle("创建", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        return button
    }()
    
    private lazy var createArrowIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_agent_setting_arrow") // 使用现有的箭头图标
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_brand_main6")

        addSubview(voiceprintIconView)
        addSubview(voiceprintTitleLabel)
        addSubview(createButton)
        addSubview(createArrowIcon)
        voiceprintIconView.addSubview(voiceprintIcon)
    }
    
    private func setupConstraints() {
        voiceprintIconView.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        voiceprintIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        voiceprintTitleLabel.snp.makeConstraints { make in
            make.left.equalTo(voiceprintIconView.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }
        
        createButton.snp.makeConstraints { make in
            make.right.equalTo(createArrowIcon.snp.left).offset(-4)
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.greaterThanOrEqualTo(40)
        }
        
        createArrowIcon.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }
    
    // MARK: - Public Methods
    
    // Expose the button for external action binding
    func bindCreateButtonAction(target: Any, action: Selector) {
        createButton.addTarget(target, action: action, for: .touchUpInside)
    }
}

// MARK: - VoiceprintModeItemView

class VoiceprintModeItemView: UIControl {
    
    private let mode: VoiceprintMode
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = mode.title
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = mode.description
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.themColor(named: "ai_icontext1").withAlphaComponent(0.5)
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_checkbox_checked")
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.isHidden = true
        return imageView
    }()
    
    init(mode: VoiceprintMode, isSelected: Bool) {
        self.mode = mode
        super.init(frame: .zero)
        setupViews()
        updateSelection(isSelected: isSelected)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(selectionIndicator)
        selectionIndicator.addSubview(checkmarkImageView)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(selectionIndicator.snp.left).offset(-16)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(3)
            make.left.equalTo(titleLabel)
            make.right.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        selectionIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }
    
    func updateSelection(isSelected: Bool) {
        self.isSelected = isSelected
        
        if isSelected {
            checkmarkImageView.isHidden = false
        } else {
            checkmarkImageView.isHidden = true
        }
    }
}
