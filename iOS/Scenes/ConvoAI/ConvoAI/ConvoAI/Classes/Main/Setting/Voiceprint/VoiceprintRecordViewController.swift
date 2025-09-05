//
//  VoiceprintRecordViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/08/26.
//

import UIKit
import SnapKit
import Common
import SVProgressHUD
import AVFoundation

// MARK: - VoiceprintRecordViewControllerDelegate
protocol VoiceprintRecordViewControllerDelegate: AnyObject {
    func voiceprintRecordViewController(_ controller: VoiceprintRecordViewController, didFinishRecording voiceprintInfo: VoiceprintInfo)
}

class VoiceprintRecordViewController: UIViewController {
    
    weak var delegate: VoiceprintRecordViewControllerDelegate?
    
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var isRecording = false
    
    private let minRecordingTime: TimeInterval = 10.0
    private let maxRecordingTime: TimeInterval = 20.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private let voiceprintManager = VoiceprintManager.shared
    
    private var tempRecordingURL: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("temp_voiceprint_recording.pcm")
    }
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        view.layer.cornerRadius = 20
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var grabberView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#404548")
        view.layer.cornerRadius = 2
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.themColor(named: "ai_btn2")
        button.layer.cornerRadius = 12
        button.setImage(UIImage.ag_named("ic_close_small"), for: .normal)
        button.tintColor = UIColor.themColor(named: "ai_icontext3")
        button.addTarget(self, action: #selector(onCloseButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.pleaseRead
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.recordingText
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.contentMode = .topLeft
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.text = String(format: ResourceManager.L10n.Voiceprint.recordingTime, 0)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Voiceprint.recordingInstruction
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var lineWaveAnimationView: LineWaveAnimationView = {
        let view = LineWaveAnimationView(lineCount: 50, lineWidth: 4, lineSpacing: 2, animationType: .fromCenter)
        return view
    }()
    
    private lazy var recordingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(hex: "#555B69")
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 0.87
        button.layer.borderColor = UIColor(hex: "#505051", alpha: 0.6)?.cgColor
        button.setTitle(ResourceManager.L10n.Voiceprint.holdToRecord, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        button.addTarget(self, action: #selector(onRecordingButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(onRecordingButtonTouchUpInside), for: .touchUpInside)
        button.addTarget(self, action: #selector(onRecordingButtonTouchUpOutside), for: .touchUpOutside)
        return button
    }()
    
    private let VIEW_HEIGHT: CGFloat = 600
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        updateUIForIdleState()
        setupAudioSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentWithAnimation()
    }
        
    private func setupViews() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        
        view.addSubview(backgroundView)
        backgroundView.addSubview(headerView)
        headerView.addSubview(grabberView)
        headerView.addSubview(closeButton)
        
        backgroundView.addSubview(titleLabel)
        backgroundView.addSubview(textLabel)
        backgroundView.addSubview(timeLabel)
        backgroundView.addSubview(instructionLabel)
        backgroundView.addSubview(recordingButton)
        recordingButton.addSubview(lineWaveAnimationView)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        headerView.addGestureRecognizer(panGesture)
    }
    
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(VIEW_HEIGHT)
        }
        
        headerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(56)
        }
        
        grabberView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(7)
            make.width.equalTo(35)
            make.height.equalTo(3.5)
        }
        
        closeButton.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.left.right.equalToSuperview().inset(14)
        }
        
        textLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.bottom.equalTo(timeLabel.snp.top).offset(-20)
            make.left.right.equalToSuperview().inset(14)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.bottom.equalTo(instructionLabel.snp.top).offset(-12)
            make.centerX.equalToSuperview()
        }
        
        instructionLabel.snp.makeConstraints { make in
            make.bottom.equalTo(recordingButton.snp.top).offset(-12)
            make.left.right.equalTo(recordingButton)
        }
        
        recordingButton.snp.makeConstraints { make in
            make.bottom.equalTo(-40)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }
        
        lineWaveAnimationView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(30)
        }
    }
        
    private func presentWithAnimation() {
        backgroundView.transform = CGAffineTransform(translationX: 0, y: VIEW_HEIGHT)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.backgroundView.transform = .identity
        }
    }
    
    private func dismissWithAnimation() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseIn) {
            self.backgroundView.transform = CGAffineTransform(translationX: 0, y: self.VIEW_HEIGHT)
            self.view.backgroundColor = UIColor(white: 0, alpha: 0)
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Recording Methods
    
    private func startRecording() {
        guard let audioSession = audioSession else { return }
        
        do {
            // Request microphone permission
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Configure recording settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            
            // Create audio recorder
            audioRecorder = try AVAudioRecorder(url: tempRecordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            // Start recording
            if audioRecorder?.record() == true {
                print("Recording started successfully")
            } else {
                print("Failed to start recording")
            }
            
        } catch {
            print("Failed to setup recording: \(error)")
            SVProgressHUD.showError(withStatus: "Failed to start recording")
        }
    }
    
    private func stopRecording(save: Bool) {
        audioRecorder?.stop()
        audioRecorder = nil
        if save {
            saveRecordedAudio()
        }
    }
    
    private func saveRecordedAudio() {
        guard
            FileManager.default.fileExists(atPath: tempRecordingURL.path),
            let audioData = try? Data(contentsOf: tempRecordingURL),
            let userId = UserCenter.user?.uid
        else {
            print("Failed to get temp directory or recording file not found or failed to read data or userId missing")
            return
        }
        
        // Save audio file with user ID as filename
        if let savedURL = voiceprintManager.saveAudioFile(data: audioData, userId: userId, fileExtension: "pcm") {
            print("Audio saved successfully at: \(savedURL)")
            // Create voiceprint info
            let info = VoiceprintInfo()
            info.localUrl = savedURL.path
            info.timestamp = Date().timeIntervalSince1970
            delegate?.voiceprintRecordViewController(self, didFinishRecording: info)
            dismiss(animated: true)
            AgentToast.showSuccess(ResourceManager.L10n.Voiceprint.recordingComplete)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempRecordingURL)
        } else {
            print("Failed to save audio file")
            AgentToast.showError("Failed to save audio file")
        }
    }
    
    private func updateUIForRecordingState() {
        isRecording = true
        recordingDuration = 0
        updateTimeLabel()
        
        titleLabel.text = ResourceManager.L10n.Voiceprint.recordingTitle
        timeLabel.isHidden = false
        instructionLabel.text = ResourceManager.L10n.Voiceprint.recordingInstruction
        instructionLabel.isHidden = false
        lineWaveAnimationView.isHidden = false
        
        recordingButton.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        recordingButton.setTitle("", for: .normal)
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRecording()
        }
        
        lineWaveAnimationView.startAnimation()
    }
    
    private func updateUIForIdleState() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        lineWaveAnimationView.stopAnimation()
        
        titleLabel.text = ResourceManager.L10n.Voiceprint.pleaseRead
        timeLabel.isHidden = true
        instructionLabel.text = ResourceManager.L10n.Voiceprint.warning
        instructionLabel.isHidden = false
        lineWaveAnimationView.isHidden = true
        
        recordingButton.backgroundColor = UIColor(hex: "#555B69")
        recordingButton.setTitle(ResourceManager.L10n.Voiceprint.holdToRecord, for: .normal)
    }
    
    private func updateRecording() {
        recordingDuration += 0.1
        updateTimeLabel()
        
        // Check if recording time exceeds maximum limit
        if recordingDuration >= maxRecordingTime {
            updateUIForIdleState()
            stopRecording(save: true)
        }
    }
    
    private func updateTimeLabel() {
        let currentTime = Int(recordingDuration)
        timeLabel.text = String(format: ResourceManager.L10n.Voiceprint.recordingTime, currentTime)
    }
    
    private func showMicroPhonePermissionAlert() {
        let title = ResourceManager.L10n.Error.microphonePermissionTitle
        let description = ResourceManager.L10n.Error.microphonePermissionDescription
        let cancel = ResourceManager.L10n.Error.permissionCancel
        let confirm = ResourceManager.L10n.Error.permissionConfirm
        AgentAlertView.show(in: view, title: title, content: description, cancelTitle: cancel, confirmTitle: confirm, onConfirm: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
    }
    
    @objc private func onRecordingButtonTouchDown() {
        PermissionManager.checkMicrophonePermission { [weak self] res in
            if res {
                self?.updateUIForRecordingState()
                self?.startRecording()
            } else {
                self?.showMicroPhonePermissionAlert()
            }
        }
    }
    
    @objc private func onRecordingButtonTouchUpInside() {
        updateUIForIdleState()
        
        if recordingDuration >= minRecordingTime {
            stopRecording(save: true)
        } else {
            stopRecording(save: false)
            SVProgressHUD.showError(withStatus: ResourceManager.L10n.Voiceprint.recordingTooShort)
        }
    }
    
    @objc private func onRecordingButtonTouchUpOutside() {
        stopRecording(save: false)
        updateUIForIdleState()
    }
    
    @objc private func onCloseButtonTapped() {
        dismissWithAnimation()
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // Move the background view with the pan gesture
            let newY = max(0, translation.y)
            backgroundView.transform = CGAffineTransform(translationX: 0, y: newY)
            
        case .ended, .cancelled:
            let shouldDismiss = translation.y > 100 || velocity.y > 500
            
            if shouldDismiss {
                dismissWithAnimation()
            } else {
                // Snap back to original position
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.backgroundView.transform = .identity
                }
            }
        default:
            break
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceprintRecordViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully")
        } else {
            print("Recording finished with error")
            SVProgressHUD.showError(withStatus: "Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
            SVProgressHUD.showError(withStatus: "Recording error occurred")
        }
    }
}
