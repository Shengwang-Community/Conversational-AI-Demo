//
//  TakePhotoViewController.swift
//  AgoraEntScenarios
//
//  Created by HeZhengQing on 2025/07/03.
//

import UIKit
import AVFoundation
import PhotosUI
import Photos
import SnapKit

class TakePhotoViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    var completion: ((UIImage?) -> Void)?

    // UI
    private let topBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let bottomBar = UIView()
    private let previewImageView = UIImageView()
    private let shutterOuterView = UIView()
    private let shutterButton = UIButton(type: .custom)
    private let switchCameraButton = UIButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        createViews()
        createConstraints()
        fetchLatestPhotoThumbnail()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = previewLayer {
            let top = topBar.frame.maxY
            let bottom = bottomBar.frame.minY
            previewLayer.frame = CGRect(x: 0, y: top, width: view.bounds.width, height: bottom - top)
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        self.captureSession = session
        self.previewLayer = preview
        self.photoOutput = output
        session.startRunning()
    }

    @objc func takePhotoAction() {
        shutterButton.isEnabled = false
        
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    @objc func closeAction() {
        dismiss(animated: true)
    }

    @objc func switchCamera() {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()
        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
        setupCamera()
    }

    @objc func openPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        shutterButton.isEnabled = true
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        let editVC = PhotoEditViewController()
        editVC.image = image
        editVC.completion = completion
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    @objc private func shutterButtonTouchDown() {
        UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseIn], animations: {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.76, y: 0.76) // 50/66
        }, completion: nil)
    }

    @objc private func shutterButtonTouchUp() {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: [], animations: {
            self.shutterButton.transform = CGAffineTransform.identity 
        }, completion: nil)
    }
}

extension TakePhotoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                let editVC = PhotoEditViewController()
                editVC.image = image
                editVC.completion = self.completion
                self.navigationController?.pushViewController(editVC, animated: true)
            }
        }
    }
}

private extension TakePhotoViewController {
    func fetchLatestPhotoThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = fetchResult.firstObject else { return }
        let manager = PHImageManager.default()
        manager.requestImage(for: asset, targetSize: CGSize(width: 48, height: 48), contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.previewImageView.image = image
        }
    }
}

// MARK: - Creation
private extension TakePhotoViewController {
    private func createViews() {
        // Top bar
        topBar.backgroundColor = UIColor.themColor(named: "ai_brand_black10")
        view.addSubview(topBar)

        // Top close button
        closeButton.setImage(UIImage.ag_named("ic_agent_setting_close"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        topBar.addSubview(closeButton)

        // Bottom bar
        bottomBar.backgroundColor = UIColor.themColor(named: "ai_brand_black10")
        view.addSubview(bottomBar)

        // Preview image
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.layer.cornerRadius = 12
        previewImageView.layer.masksToBounds = true
        previewImageView.isUserInteractionEnabled = true
        let tapPreview = UITapGestureRecognizer(target: self, action: #selector(openPhotoPicker))
        previewImageView.addGestureRecognizer(tapPreview)
        bottomBar.addSubview(previewImageView)

        shutterOuterView.backgroundColor = .clear
        shutterOuterView.layer.cornerRadius = 38
        shutterOuterView.layer.borderWidth = 4
        shutterOuterView.layer.borderColor = UIColor.themColor(named: "ai_brand_white10").cgColor
        bottomBar.addSubview(shutterOuterView)

        shutterButton.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        shutterButton.layer.cornerRadius = 33
        shutterButton.layer.masksToBounds = true
        shutterButton.addTarget(self, action: #selector(takePhotoAction), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(shutterButtonTouchDown), for: .touchDown)
        shutterButton.addTarget(self, action: #selector(shutterButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        bottomBar.addSubview(shutterButton)

        // Switch camera button
        switchCameraButton.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        switchCameraButton.layer.cornerRadius = 26
        switchCameraButton.setImage(UIImage.ag_named("ic_photo_camera_switch"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        bottomBar.addSubview(switchCameraButton)
    }

    private func createConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(66)
        }
        closeButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        bottomBar.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(170)
        }
        previewImageView.snp.makeConstraints { make in
            make.left.equalTo(bottomBar).offset(38)
            make.centerY.equalTo(bottomBar)
            make.width.height.equalTo(52)
        }
        shutterOuterView.snp.makeConstraints { make in
            make.centerX.equalTo(bottomBar)
            make.centerY.equalTo(bottomBar)
            make.width.height.equalTo(76)
        }
        shutterButton.snp.makeConstraints { make in
            make.center.equalTo(shutterOuterView)
            make.width.height.equalTo(66)
        }
        switchCameraButton.snp.makeConstraints { make in
            make.right.equalTo(bottomBar).offset(-38)
            make.centerY.equalTo(bottomBar)
            make.width.height.equalTo(52)
        }
    }
}
