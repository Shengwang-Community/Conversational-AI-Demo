//
//  VoiceprintInfoTabView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/26.
//

import UIKit
import SnapKit
import Common

enum VoiceprintRecordStatus {
    case notCreated      // 未创建状态
    case uploading       // 上传中状态
    case uploadFailed    // 上传失败状态
    case created         // 已创建状态
    case playing         // 播放状态
}

class VoiceprintInfoTabView: UIView {
    
    // MARK: - Properties
    
    private var currentStatus: VoiceprintRecordStatus = .notCreated
    private var voiceprintDate: String = ""
    private var isPlaying = false
    
    // MARK: - UI Components
    
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
        label.text = ResourceManager.L10n.VoiceprintMode.createTitle
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        return label
    }()
    
    private lazy var voiceprintDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.isHidden = true
        return label
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.isHidden = true
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.isHidden = true
        return indicator
    }()
    
    private lazy var errorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.red.withAlphaComponent(0.2)
        view.layer.cornerRadius = 4
        view.isHidden = true
        return view
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.VoiceprintMode.uploadFailed
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_agent_setting_close"), for: .normal) // 使用刷新图标
        button.tintColor = .white
        button.isHidden = true
        return button
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_agent_mute"), for: .normal) // 使用播放图标
        button.tintColor = .white
        button.isHidden = true
        return button
    }()
    
    private lazy var waveformView: LineWaveAnimationView = {
        let view = LineWaveAnimationView(lineCount: 20, lineWidth: 2, lineSpacing: 1, animationType: .fromCenter)
        view.isHidden = true
        return view
    }()
    
    lazy var createButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 8
        button.setTitle(ResourceManager.L10n.VoiceprintMode.createButton, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        return button
    }()
    
    lazy var reRecordButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 8
        button.setTitle(ResourceManager.L10n.VoiceprintMode.reRecordButton, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        button.isHidden = true
        return button
    }()
    
    private lazy var createArrowIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_agent_setting_arrow")
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
        addSubview(voiceprintDateLabel)
        addSubview(statusLabel)
        addSubview(loadingIndicator)
        addSubview(errorView)
        addSubview(retryButton)
        addSubview(playButton)
        addSubview(waveformView)
        addSubview(createButton)
        addSubview(reRecordButton)
        addSubview(createArrowIcon)
        
        voiceprintIconView.addSubview(voiceprintIcon)
        errorView.addSubview(errorLabel)
        
        // Add button actions
        retryButton.addTarget(self, action: #selector(onRetryButtonTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(onPlayButtonTapped), for: .touchUpInside)
        reRecordButton.addTarget(self, action: #selector(onReRecordButtonTapped), for: .touchUpInside)
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
            make.centerY.equalTo(voiceprintIcon)
        }
        
        voiceprintDateLabel.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel)
            make.top.equalTo(voiceprintTitleLabel.snp.bottom).offset(2)
        }
        
        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel)
            make.top.equalTo(voiceprintTitleLabel.snp.bottom).offset(2)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.left.equalTo(statusLabel.snp.right).offset(8)
            make.centerY.equalTo(statusLabel)
            make.width.height.equalTo(16)
        }
        
        errorView.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel)
            make.right.equalTo(retryButton.snp.left).offset(-8)
            make.top.equalTo(voiceprintTitleLabel.snp.bottom).offset(2)
            make.height.equalTo(20)
        }
        
        errorLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        retryButton.snp.makeConstraints { make in
            make.right.equalTo(createArrowIcon.snp.left).offset(-4)
            make.centerY.equalTo(errorView)
            make.width.height.equalTo(16)
        }
        
        playButton.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel.snp.right).offset(8)
            make.centerY.equalTo(voiceprintTitleLabel)
            make.width.height.equalTo(20)
        }
        
        waveformView.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel.snp.right).offset(8)
            make.centerY.equalTo(voiceprintTitleLabel)
            make.height.equalTo(20)
            make.width.equalTo(40)
        }
        
        createButton.snp.makeConstraints { make in
            make.right.equalTo(createArrowIcon.snp.left).offset(-4)
            make.bottom.equalTo(-16)
            make.height.equalTo(24)
            make.width.greaterThanOrEqualTo(40)
        }
        
        reRecordButton.snp.makeConstraints { make in
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
    
    func bindCreateButtonAction(target: Any, action: Selector) {
        createButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    func updateStatus(_ status: VoiceprintRecordStatus, date: String = "") {
        currentStatus = status
        voiceprintDate = date
        updateUIForStatus()
    }
    
    func setVoiceprintInfo(date: String) {
        voiceprintDate = date
        voiceprintDateLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, date)
    }
    
    // MARK: - Private Methods
    
    private func updateUIForStatus() {
        // Reset all UI elements
        voiceprintDateLabel.isHidden = true
        statusLabel.isHidden = true
        loadingIndicator.isHidden = true
        errorView.isHidden = true
        retryButton.isHidden = true
        playButton.isHidden = true
        waveformView.isHidden = true
        createButton.isHidden = false
        reRecordButton.isHidden = true
        
        switch currentStatus {
        case .notCreated:
            voiceprintTitleLabel.text = ResourceManager.L10n.VoiceprintMode.createTitle
            createButton.setTitle(ResourceManager.L10n.VoiceprintMode.createButton, for: .normal)
            
        case .uploading:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            statusLabel.text = ResourceManager.L10n.VoiceprintMode.uploading
            statusLabel.isHidden = false
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            createButton.setTitle("", for: .normal)
            
        case .uploadFailed:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            errorView.isHidden = false
            retryButton.isHidden = false
            createButton.setTitle("", for: .normal)
            
        case .created:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            voiceprintDateLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            voiceprintDateLabel.isHidden = false
            playButton.isHidden = false
            createButton.isHidden = true
            reRecordButton.isHidden = false
            reRecordButton.setTitle(ResourceManager.L10n.VoiceprintMode.reRecordButton, for: .normal)
            
        case .playing:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            voiceprintDateLabel.text = String(format: ResourceManager.L10n.VoiceprintMode.dateFormat, voiceprintDate)
            voiceprintDateLabel.isHidden = false
            waveformView.isHidden = false
            waveformView.startAnimation()
            createButton.isHidden = true
            reRecordButton.isHidden = false
            reRecordButton.setTitle(ResourceManager.L10n.VoiceprintMode.reRecordButton, for: .normal)
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func onRetryButtonTapped() {
        // TODO: Implement retry logic
        updateStatus(.uploading, date: voiceprintDate)
    }
    
    @objc private func onPlayButtonTapped() {
        if isPlaying {
            // Stop playing
            isPlaying = false
            waveformView.stopAnimation()
            updateStatus(.created, date: voiceprintDate)
        } else {
            // Start playing
            isPlaying = true
            updateStatus(.playing, date: voiceprintDate)
        }
        // TODO: Implement play/stop logic
    }
    
    @objc private func onReRecordButtonTapped() {
        // TODO: Implement re-record logic
        updateStatus(.notCreated)
    }
}
