//  VoiceprintViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/26.
//

import UIKit
import SnapKit
import Common
import SVProgressHUD
import AVFoundation

// MARK: - VoiceprintMode Extension
extension VoiceprintMode {
    var title: String {
        switch self {
        case .off:
            return ResourceManager.L10n.Voiceprint.off
        case .seamless:
            return ResourceManager.L10n.Voiceprint.seamless
        case .aware:
            return ResourceManager.L10n.Voiceprint.aware
        }
    }
    
    var description: String {
        switch self {
        case .off:
            return ResourceManager.L10n.Voiceprint.offDescription
        case .seamless:
            return ResourceManager.L10n.Voiceprint.seamlessDescription
        case .aware:
            return ResourceManager.L10n.Voiceprint.awareDescription
        }
    }
}

class VoiceprintViewController: BaseViewController, VoiceprintRecordViewControllerDelegate {
    
    private var isVoiceprintTabVisible = false
    private var voiceprintInfo: VoiceprintInfo? = nil
    private var currentMode = AppContext.preferenceManager()?.preference.voiceprintMode ?? .off
    private var audioPlayer: AVAudioPlayer?
    private var toolBox = ToolBoxApiManager()
    
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
    
    private lazy var voiceprintTipView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        
        // Create gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#659EFA")?.cgColor,
            UIColor(hex: "#655FFF")?.cgColor
        ].compactMap { $0 }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = 6
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Store gradient layer for later updates
        view.layer.setValue(gradientLayer, forKey: "gradientLayer")
        
        return view
    }()
    
    private lazy var tipIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_voiceprint_wave_tips")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.tipText
        label.font = .systemFont(ofSize: 8, weight: .semibold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var voiceprintInfoTab: VoiceprintInfoTabView = {
        let view = VoiceprintInfoTabView()
        view.retryButton.addTarget(self, action: #selector(onRetryButtonTapped), for: .touchUpInside)
        view.playButton.addTarget(self, action: #selector(onPlayButtonTapped), for: .touchUpInside)
        view.gotoButton.addTarget(self, action: #selector(onGotoButtonTapped), for: .touchUpInside)
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.layer.masksToBounds = true
        return view
    }()
    
    // Constraint for voiceprint info tab animation
    private var voiceprintInfoTabTopConstraint: Constraint?
    private let TAB_SHOW: CGFloat = -20
    private let TAB_HIDE: CGFloat = -108
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationTitle = ResourceManager.L10n.Voiceprint.lockTitle
        setupViews()
        setupConstraints()
        setupModeItems()
        loadVoiceprintInfo()
    }
    
    override func shouldEnablePopGesture() -> Bool {
        return true
    }
    
    override func navigationBackButtonTapped() {
        if readyPop() {
            AppContext.preferenceManager()?.updateVoiceprintMode(currentMode)
            self.navigationController?.popViewController(animated: true)
        } else {
            VoiceprintAlertView.show(
                in: view,
                title: ResourceManager.L10n.Voiceprint.alertNoVoiceprintTitle,
                content: ResourceManager.L10n.Voiceprint.alertNoVoiceprintContent,
                onCancel: {
                    // User cancelled, do nothing
                },
                onConfirm: { [weak self] in
                    if let userId = UserCenter.user?.uid {
                        // if no remote file, delete local file
                        let _ = VoiceprintManager.shared.deleteAudioFile(userId: userId)
                        // remove timestamp
                        self?.voiceprintInfo?.timestamp = nil
                        if let p = self?.voiceprintInfo {
                            VoiceprintManager.shared.saveVoiceprint(p, forUserId: userId)
                        }
                    }
                    self?.navigationController?.popViewController(animated: true)
                }
            )
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient layer frame
        if let gradientLayer = voiceprintTipView.layer.value(forKey: "gradientLayer") as? CAGradientLayer {
            gradientLayer.frame = voiceprintTipView.bounds
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVoiceprintPlayback()
    }
    
    private func readyPop() -> Bool {
        if currentMode == .aware {
            if let info = voiceprintInfo, info.remoteUrl != nil {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    private func setupViews() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.addSubview(voiceprintInfoTab)
        view.addSubview(groupedListView)
        
        // Setup voiceprint tip view
        voiceprintTipView.addSubview(tipIconImageView)
        voiceprintTipView.addSubview(tipLabel)
    }
    
    private func setupConstraints() {
        groupedListView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom).offset(20)
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.height.lessThanOrEqualTo(500)
        }
        
        tipIconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(6)
            make.centerY.equalToSuperview()
        }
        
        tipLabel.snp.makeConstraints { make in
            make.left.equalTo(tipIconImageView.snp.right).offset(4)
            make.right.equalToSuperview().offset(-6)
            make.centerY.equalToSuperview()
        }
        
        voiceprintInfoTab.snp.makeConstraints { make in
            voiceprintInfoTabTopConstraint = make.top.equalTo(groupedListView.snp.bottom).offset(-108).constraint
            make.width.centerX.equalTo(groupedListView)
            make.height.equalTo(108)
        }
    }
    
    private func setupModeItems() {
        for (index, mode) in VoiceprintMode.allCases.enumerated() {
            let itemView = VoiceprintModeItemView(mode: mode, isSelected: mode == currentMode)
            itemView.tag = index
            itemView.addTarget(self, action: #selector(modeItemTapped(_:)), for: .touchUpInside)
            
            groupedListView.addArrangedSubview(itemView)
            modeItems.append(itemView)
            
            // Add voiceprint tip view to aware mode item
            if mode == .aware {
                itemView.addSubview(voiceprintTipView)
                voiceprintTipView.snp.makeConstraints { make in
                    make.centerY.equalTo(itemView.titleLabel)
                    make.left.equalTo(itemView.titleLabel.snp.right).offset(8)
                    make.height.equalTo(18)
                }
            }
            
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
    
    func updateSelectedMode() {
        for (index, itemView) in modeItems.enumerated() {
            let isSelected = VoiceprintMode.allCases[index] == currentMode
            itemView.updateSelection(isSelected: isSelected)
        }
    }
    
    private func loadVoiceprintInfo() {
        guard let userId = UserCenter.user?.uid else { return}
        voiceprintInfo = VoiceprintManager.shared.getVoiceprint(forUserId: userId)
        // Update selected mode based on current mode
        updateSelectedMode()
        
        if let info = voiceprintInfo,
           let ts = info.timestamp {
            voiceprintInfoTab.setVoiceprintDate(timestamp: ts)
            voiceprintTipView.isHidden = false
            if info.remoteUrl != nil {
                voiceprintInfoTab.updateStatus(.created)
            } else {
                voiceprintInfoTab.updateStatus(.uploadFailed)
            }
        } else {
            voiceprintInfoTab.updateStatus(.notCreated)
            voiceprintTipView.isHidden = true
        }
        // Set initial state based on current mode
        if currentMode == .aware {
            showvoiceprintInfoTab(animated: false)
            checkNeedUpdateRemote()
        } else {
            hidevoiceprintInfoTab(animated: false)
        }
    }
    
    private func checkNeedUpdateRemote() {
        guard
            let info = voiceprintInfo,
            let _ = info.timestamp
        else {
            // no local file
            return
        }
        if info.remoteUrl == nil ||
            info.needToUpdate() == true {
            uploadVoiceprint()
        }
    }
    
    private func uploadVoiceprint() {
        guard
            let userId = UserCenter.user?.uid,
            let audioFileURL = VoiceprintManager.shared.getAudioFileURL(userId: userId),
            FileManager.default.fileExists(atPath: audioFileURL.path)
        else {
            AgentToast.showWarn(ResourceManager.L10n.Voiceprint.uploadFailed)
            voiceprintInfoTab.updateStatus(.notCreated)
            return
        }
        voiceprintInfoTab.updateStatus(.uploading)
        toolBox.uploadFile(filePath: audioFileURL.path) { [weak self] remoteUrl in
            guard let self = self else { return }
            if let remoteUrl = remoteUrl, !remoteUrl.isEmpty {
                self.voiceprintInfo?.remoteUrl = remoteUrl
                self.voiceprintInfo?.timestamp = TimeUtils.currentTimeMillis() / 1000
                if let p = self.voiceprintInfo {
                    VoiceprintManager.shared.saveVoiceprint(p, forUserId: userId)
                }
                self.voiceprintInfoTab.updateStatus(.created)
                AgentToast.showSuccess(ResourceManager.L10n.Voiceprint.uploadSuccess)
            } else {
                self.voiceprintInfoTab.updateStatus(.uploadFailed)
                AgentToast.showWarn(ResourceManager.L10n.Voiceprint.uploadFailed)
            }
        } failure: { [weak self] info in
            self?.voiceprintInfoTab.updateStatus(.uploadFailed)
            AgentToast.showWarn(info)
        }
    }
    
    @objc private func onRetryButtonTapped() {
        uploadVoiceprint()
    }
    
    @objc private func onPlayButtonTapped() {
        if voiceprintInfoTab.getCurrentStatus() == .playing {
            // Stop playing
            stopVoiceprintPlayback()
        } else {
            // Start playing
            startVoiceprintPlayback()
        }
    }
    
    @objc private func onGotoButtonTapped() {
        CommonAlertView.show(
            in: view,
            title: ResourceManager.L10n.Voiceprint.alertTitle,
            content: ResourceManager.L10n.Voiceprint.alertContent,
            cancelTitle: ResourceManager.L10n.Voiceprint.alertCancel,
            confirmTitle: ResourceManager.L10n.Voiceprint.alertConfirm,
            onConfirm: { [weak self] _ in
                // Present voiceprint record view controller after confirmation
                let recordViewController = VoiceprintRecordViewController()
                recordViewController.delegate = self
                recordViewController.modalPresentationStyle = .overFullScreen
                recordViewController.modalTransitionStyle = .crossDissolve
                self?.present(recordViewController, animated: true)
            },
            onCancel: {
                // User cancelled, do nothing
            }
        )
    }
    
    @objc private func modeItemTapped(_ sender: VoiceprintModeItemView) {
        let selectedIndex = sender.tag
        guard selectedIndex < VoiceprintMode.allCases.count else { return }
        let newMode = VoiceprintMode.allCases[selectedIndex]
        if newMode == currentMode {
            return
        }
        let previousMode = currentMode
        updateMode(newMode)
        if newMode == .seamless {
            CommonAlertView.show(
                in: view,
                title: ResourceManager.L10n.Voiceprint.alertTitle,
                content: ResourceManager.L10n.Voiceprint.alertSeamlessContent,
                cancelTitle: ResourceManager.L10n.Voiceprint.alertCancel,
                confirmTitle: ResourceManager.L10n.Voiceprint.alertConfirm,
                onConfirm: { _ in },
                onCancel: { [weak self] in
                    self?.updateMode(previousMode)
                }
            )
        }
    }
    
    private func updateMode(_ newMode: VoiceprintMode) {
        currentMode = newMode
        updateSelectedMode()
        
        // Show/hide voiceprint creation tab based on mode
        if newMode == .aware {
            showvoiceprintInfoTab()
            checkNeedUpdateRemote()
        } else {
            hidevoiceprintInfoTab()
            stopVoiceprintPlayback()
        }
        
        // Update preference manager
        AppContext.preferenceManager()?.updateVoiceprintMode(newMode)
    }
    
    private func showvoiceprintInfoTab(animated: Bool = true) {
        guard !isVoiceprintTabVisible else { return }
        isVoiceprintTabVisible = true
        voiceprintInfoTabTopConstraint?.update(offset: TAB_SHOW)
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                self.view.layoutIfNeeded()
            }
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    private func hidevoiceprintInfoTab(animated: Bool = true) {
        guard isVoiceprintTabVisible else { return }
        isVoiceprintTabVisible = false
        voiceprintInfoTabTopConstraint?.update(offset: TAB_HIDE)
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseIn) {
                self.view.layoutIfNeeded()
            }
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Voiceprint Playback Methods
    
    private func startVoiceprintPlayback() {
        guard let userId = UserCenter.user?.uid else { return }
        stopVoiceprintPlayback()
        guard
            let audioFileURL = VoiceprintManager.shared.getAudioFileURL(userId: userId),
            FileManager.default.fileExists(atPath: audioFileURL.path)
        else {
            SVProgressHUD.showError(withStatus: "Audio file not found")
            return
        }
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create audio player
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Start playback
            if audioPlayer?.play() == true {
                voiceprintInfoTab.updateStatus(.playing)
                print("Started playing voiceprint audio")
            } else {
                SVProgressHUD.showError(withStatus: "Failed to start audio playback")
            }
        } catch {
            SVProgressHUD.showError(withStatus: "Error setting up audio playback")
        }
    }
    
    private func stopVoiceprintPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        // Update UI
        if voiceprintInfoTab.getCurrentStatus() == .playing {
            voiceprintInfoTab.updateStatus(.created)
        }
        
        print("Stopped voiceprint playback")
    }
}

// MARK: - VoiceprintRecordViewControllerDelegate
extension VoiceprintViewController {
    func voiceprintRecordViewController(_ controller: VoiceprintRecordViewController, didFinishRecording voiceprintInfo: VoiceprintInfo) {
        guard let userId = UserCenter.user?.uid else { return }
        // Save voiceprint info to file
        if VoiceprintManager.shared.saveVoiceprint(voiceprintInfo, forUserId: userId) {
            print("Voiceprint info saved successfully")
        } else {
            print("Failed to save voiceprint info")
        }
        loadVoiceprintInfo()
    }
}

// MARK: - AVAudioPlayerDelegate
extension VoiceprintViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Audio playback finished, update UI
        DispatchQueue.main.async { [weak self] in
            self?.stopVoiceprintPlayback()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Audio playback error, update UI
        DispatchQueue.main.async { [weak self] in
            self?.stopVoiceprintPlayback()
            if let error = error {
                print("Audio playback error: \(error)")
                SVProgressHUD.showError(withStatus: "Audio playback error")
            }
        }
    }
}

// MARK: - VoiceprintModeItemView
class VoiceprintModeItemView: UIControl {
    
    private let mode: VoiceprintMode
    
    public lazy var titleLabel: UILabel = {
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
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.left.equalTo(titleLabel)
            make.right.equalTo(checkmarkImageView.snp.left).offset(-16)
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
