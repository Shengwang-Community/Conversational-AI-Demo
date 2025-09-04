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
    case notCreated      // Not created
    case uploading       // Uploading
    case uploadFailed    // Upload failed
    case created         // Created
    case playing         // Playing
}

class VoiceprintInfoTabView: UIView {
    
    // MARK: - Properties
    
    private var currentStatus: VoiceprintRecordStatus = .notCreated
    private var voiceprintDate: String = ""
    
    private lazy var voiceprintIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_voiceprint_voice")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var voiceprintTitleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.createTitle
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        return label
    }()
    
    private lazy var uploadContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        view.layer.cornerRadius = 8
        view.isHidden = true
        return view
    }()
    
    private lazy var uploadLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.uploading
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        return indicator
    }()
    
    private lazy var retryContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_red6")
        view.layer.cornerRadius = 12
        view.isHidden = true
        return view
    }()
    
    private lazy var retryLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.uploadFailed
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .white
        return label
    }()
    
    public lazy var retryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_voiceprint_retry"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private lazy var playActionContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    
    public lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_voiceprint_play"), for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        return button
    }()
    
    private lazy var waveformView: LineWaveAnimationView = {
        let view = LineWaveAnimationView(lineCount: 4, lineWidth: 5, lineSpacing: 6, animationType: .fromLeft)
        return view
    }()
    
    private lazy var gotoContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    public lazy var gotoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        button.layer.cornerRadius = 8
        return button
    }()
    
    private lazy var gotoLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = .systemFont(ofSize: 12, weight: .regular)
        return label
    }()
    
    private lazy var gotoIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_voiceprint_goto")
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

        addSubview(voiceprintIcon)
        addSubview(voiceprintTitleLabel)
        addSubview(uploadContainer)
        uploadContainer.addSubview(uploadLabel)
        uploadContainer.addSubview(loadingIndicator)
        addSubview(retryContainer)
        retryContainer.addSubview(retryLabel)
        retryContainer.addSubview(retryButton)
        addSubview(playActionContainer)
        playActionContainer.addSubview(playButton)
        playActionContainer.addSubview(waveformView)
        addSubview(gotoContainer)
        gotoContainer.addSubview(gotoLabel)
        gotoContainer.addSubview(gotoIcon)
        gotoContainer.addSubview(gotoButton)
    }
    
    private func setupConstraints() {
        voiceprintIcon.snp.makeConstraints { make in
            make.top.equalTo(26)
            make.left.equalTo(16)
            make.width.height.equalTo(30)
        }
        
        voiceprintTitleLabel.snp.makeConstraints { make in
            make.left.equalTo(voiceprintIcon.snp.right).offset(12)
            make.centerY.equalTo(voiceprintIcon)
        }
        
        uploadContainer.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel)
            make.height.equalTo(24)
            make.right.equalTo(uploadLabel).offset(10)
            make.centerY.equalTo(gotoButton)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        uploadLabel.snp.makeConstraints { make in
            make.left.equalTo(loadingIndicator.snp.right).offset(8)
            make.centerY.equalToSuperview()
        }
                
        retryContainer.snp.makeConstraints { make in
            make.left.equalTo(voiceprintTitleLabel)
            make.height.equalTo(24)
            make.centerY.equalTo(gotoButton)
        }
        
        retryLabel.snp.makeConstraints { make in
            make.left.equalTo(8)
            make.centerY.equalToSuperview()
        }
        
        retryButton.snp.makeConstraints { make in
            make.left.equalTo(retryLabel.snp.right).offset(8)
            make.top.right.bottom.equalToSuperview()
        }
        
        playActionContainer.snp.makeConstraints { make in
            make.left.equalTo(voiceprintIcon.snp.right).offset(8)
            make.top.equalTo(voiceprintIcon.snp.bottom).offset(12)
            make.height.equalTo(24)
            make.width.equalTo(48)
        }
        
        playButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        waveformView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gotoContainer.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.bottom.equalTo(-16)
            make.height.equalTo(24)
            make.left.equalTo(gotoLabel.snp.left).offset(-16)
        }
        
        gotoIcon.snp.makeConstraints { make in
            make.right.equalTo(-8)
            make.centerY.equalToSuperview()
        }
        
        gotoLabel.snp.makeConstraints { make in
            make.right.equalTo(gotoIcon.snp.left).offset(-4)
            make.centerY.equalToSuperview()
        }
        
        gotoButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func getCurrentStatus() -> VoiceprintRecordStatus {
        return currentStatus
    }
    
    func updateStatus(_ status: VoiceprintRecordStatus) {
        currentStatus = status
        updateUIForStatus()
    }
    
    func setVoiceprintDate(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        voiceprintDate = formatter.string(from: date)
        updateUIForStatus()
    }
    
    func setVoiceprintDate(timestamp: TimeInterval) {
        if timestamp > 0 {
            let date = Date(timeIntervalSince1970: timestamp)
            setVoiceprintDate(date)
        } else {
            voiceprintDate = ""
            updateUIForStatus()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUIForStatus() {
        uploadContainer.isHidden = true
        retryContainer.isHidden = true
        playActionContainer.isHidden = true
        playButton.isHidden = true
        waveformView.isHidden = true
        loadingIndicator.stopAnimating()
        waveformView.stopAnimation()
        
        switch currentStatus {
        case .notCreated:
            voiceprintTitleLabel.text = ResourceManager.L10n.Voiceprint.createTitle
            gotoLabel.text = ResourceManager.L10n.Voiceprint.createButton
            gotoButton.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        case .uploading:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.Voiceprint.dateFormat, voiceprintDate)
            uploadContainer.isHidden = false
            loadingIndicator.startAnimating()

            gotoLabel.text = ""
            gotoButton.backgroundColor = .clear
        case .uploadFailed:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.Voiceprint.dateFormat, voiceprintDate)
            retryContainer.isHidden = false
            gotoButton.backgroundColor = .clear
        case .created:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.Voiceprint.dateFormat, voiceprintDate)
            playActionContainer.isHidden = false
            playButton.isHidden = false
            gotoLabel.text = ResourceManager.L10n.Voiceprint.reRecordButton
            gotoButton.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        case .playing:
            voiceprintTitleLabel.text = String(format: ResourceManager.L10n.Voiceprint.dateFormat, voiceprintDate)
            playActionContainer.isHidden = false
            waveformView.startAnimation()
            waveformView.isHidden = false
            gotoLabel.text = ResourceManager.L10n.Voiceprint.reRecordButton
            gotoButton.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        }
    }
}
