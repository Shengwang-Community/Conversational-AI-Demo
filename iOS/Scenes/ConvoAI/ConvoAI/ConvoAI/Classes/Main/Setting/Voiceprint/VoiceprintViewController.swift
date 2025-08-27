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
        
    private lazy var voiceprintCreationTab: VoiceprintInfoTabView = {
        let view = VoiceprintInfoTabView()
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
    
    private lazy var checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_digital_human_circle")
        imageView.contentMode = .scaleAspectFit
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
        addSubview(checkmarkImageView)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalTo(checkmarkImageView.snp.left).offset(-16)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.left.equalTo(titleLabel)
            make.right.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }
    }
    
    func updateSelection(isSelected: Bool) {
        self.isSelected = isSelected
        
        if isSelected {
            checkmarkImageView.image = UIImage.ag_named("ic_digital_human_circle_s")
        } else {
            checkmarkImageView.image = UIImage.ag_named("ic_digital_human_circle")
        }
    }
}
