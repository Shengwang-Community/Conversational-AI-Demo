//
//  PhotoPickTypeViewController.swift
//  AgoraEntScenarios
//
//  Created by HeZhengQing on 2025/07/03.
//

import UIKit
import PhotosUI
import SnapKit
import Common
import Photos
import SVProgressHUD
import AVFoundation

class PhotoPickTypeViewController: UIViewController {
    private var completion: ((PhotoResult?) -> Void)?
    
    private let tabView = UIView()
    private let contentView = UIView()
    private let closeButton = UIButton(type: .system)
    private let photoOptionView = UIView()
    private let photoImageView = UIImageView()
    private let photoLabel = UILabel()
    private let cameraOptionView = UIView()
    private let cameraImageView = UIImageView()
    private let cameraLabel = UILabel()
    
    private let contentViewHeight: CGFloat = 180

    static func start(from presentingVC: UIViewController, completion: @escaping (PhotoResult?) -> Void) {
        let pickVC = PhotoPickTypeViewController()
        pickVC.completion = completion
        let nav = UINavigationController(rootViewController: pickVC)
        nav.modalPresentationStyle = .overCurrentContext
        presentingVC.present(nav, animated: false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createViews()
        createConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        contentView.transform = CGAffineTransform(translationX: 0, y: contentViewHeight)
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.contentView.transform = .identity
        }
    }

    // MARK: - Creation
    private func createViews() {
        // Semi-transparent background
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        // Content container with only top corners rounded
        contentView.backgroundColor = UIColor.themColor(named: "ai_fill2")
        contentView.layer.cornerRadius = 16
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.masksToBounds = true
        view.addSubview(contentView)
        
        // Divider - optimized styling
        tabView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        tabView.layer.cornerRadius = 3
        tabView.layer.masksToBounds = true
        contentView.addSubview(tabView)

        // Top close button (add to contentView)
        closeButton.setImage(UIImage.ag_named("ic_agent_setting_close"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        contentView.addSubview(closeButton)

        // Photo option
        photoOptionView.backgroundColor = UIColor.themColor(named: "ai_block2")
        photoOptionView.layer.cornerRadius = 12
        photoOptionView.isUserInteractionEnabled = true
        let tapPhoto = UITapGestureRecognizer(target: self, action: #selector(pickPhoto))
        photoOptionView.addGestureRecognizer(tapPhoto)
        contentView.addSubview(photoOptionView)

        photoImageView.image = UIImage.ag_named("ic_photo_type_picture")
        photoImageView.contentMode = .scaleAspectFit
        photoOptionView.addSubview(photoImageView)

        photoLabel.text = ResourceManager.L10n.Photo.typePhoto
        photoLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        photoLabel.font = UIFont.systemFont(ofSize: 12)
        photoLabel.textAlignment = .center
        photoOptionView.addSubview(photoLabel)

        // Camera option
        cameraOptionView.backgroundColor = UIColor.themColor(named: "ai_block2")
        cameraOptionView.layer.cornerRadius = 12
        cameraOptionView.isUserInteractionEnabled = true
        let tapCamera = UITapGestureRecognizer(target: self, action: #selector(takePhoto))
        cameraOptionView.addGestureRecognizer(tapCamera)
        contentView.addSubview(cameraOptionView)

        cameraImageView.image = UIImage.ag_named("ic_photo_type_camera")
        cameraImageView.contentMode = .scaleAspectFit
        cameraOptionView.addSubview(cameraImageView)

        cameraLabel.text = ResourceManager.L10n.Photo.typeCamera
        cameraLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        cameraLabel.font = UIFont.systemFont(ofSize: 12)
        cameraLabel.textAlignment = .center
        cameraOptionView.addSubview(cameraLabel)
        
        // Add tap gesture to dismiss when tapping background
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Add pan gesture to dismiss when dragging down
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        contentView.addGestureRecognizer(panGesture)
    }

    private func createConstraints() {
        contentView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(180)
        }
        tabView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(7)
            make.height.equalTo(4)
            make.width.equalTo(34)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(32)
        }
        let buttonWidth = (UIScreen.main.bounds.width - 48) / 2
        photoOptionView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.width.equalTo(buttonWidth)
            make.top.equalTo(56)
            make.bottom.equalTo(-40)
        }
        cameraOptionView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(buttonWidth)
            make.top.equalTo(56)
            make.bottom.equalTo(-40)
        }
        
        // Image and label vertical layout
        photoImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(32)
        }
        photoLabel.snp.makeConstraints { make in
            make.top.equalTo(photoImageView.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.height.equalTo(22)
        }
        cameraImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(32)
        }
        cameraLabel.snp.makeConstraints { make in
            make.top.equalTo(cameraImageView.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.height.equalTo(22)
        }
    }

    // MARK: - Gesture Handlers
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !contentView.frame.contains(location) {
            closeAction()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: contentView)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                contentView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: contentView)
            if translation.y > 60 || velocity.y > 500 { // Close if dragged more than 60 or velocity exceeds 500
                closeAction()
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.contentView.transform = .identity
                }
            }
        default:
            break
        }
    }

    @objc private func closeAction() {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn], animations: {
            self.contentView.transform = CGAffineTransform(translationX: 0, y: self.contentView.bounds.height)
        }) { _ in
            self.dismiss(animated: false)
        }
    }

    @objc func pickPhoto() {
        checkPhotoLibraryPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                var config = PHPickerConfiguration()
                config.selectionLimit = 1
                config.filter = .images
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.present(picker, animated: true)
            } else {
                self.showPermissionAlert(for: .photoLibrary)
            }
        }
    }

    @objc func takePhoto() {
        checkCameraPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.checkPhotoPreviewPermission()
            } else {
                self.showPermissionAlert(for: .camera)
            }
        }
    }
    
    /// Check photo permission for camera preview functionality
    private func checkPhotoPreviewPermission() {
        checkPhotoLibraryPermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                // Both permissions granted, proceed to camera
                self.proceedToCamera()
            } else {
                // Camera permission granted but photo library denied
                // Show optional permission dialog
                self.showPermissionAlert(for: .photoPreview)
            }
        }
    }
    
    /// Proceed to camera screen
    private func proceedToCamera() {
        let takeVC = TakePhotoViewController()
        takeVC.completion = self.completion
        self.navigationController?.pushViewController(takeVC, animated: true)
    }
    
    // MARK: - Permission Methods
    
    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private enum PermissionType {
        case photoLibrary      // Photo library permission for selecting photos
        case camera           // Camera permission for taking photos  
        case photoPreview     // Photo library permission for camera preview (optional)
    }
    
    private func showPermissionAlert(for type: PermissionType) {
        let title: String
        let message: String
        var showSkipOption = false
        
        switch type {
        case .photoLibrary:
            title = ResourceManager.L10n.Photo.permissionPhotoTitle
            message = ResourceManager.L10n.Photo.permissionPhotoMessage
        case .camera:
            title = ResourceManager.L10n.Photo.permissionCameraTitle
            message = ResourceManager.L10n.Photo.permissionCameraMessage
        case .photoPreview:
            title = ResourceManager.L10n.Photo.permissionPhotoPreviewTitle
            message = ResourceManager.L10n.Photo.permissionPhotoPreviewMessage
            showSkipOption = true
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Cancel action
        alert.addAction(UIAlertAction(title: ResourceManager.L10n.Photo.permissionCancel, style: .cancel))
        
        if showSkipOption {
            // For photo preview permission, show skip option
            alert.addAction(UIAlertAction(title: ResourceManager.L10n.Photo.permissionSkip, style: .default) { [weak self] _ in
                // Skip photo permission and proceed to camera
                self?.proceedToCamera()
            })
            
            // Enable permission action
            alert.addAction(UIAlertAction(title: ResourceManager.L10n.Photo.permissionEnable, style: .default) { [weak self] _ in
                self?.requestPhotoLibraryPermission()
            })
        } else {
            // For required permissions, show settings action
            alert.addAction(UIAlertAction(title: ResourceManager.L10n.Photo.permissionSettings, style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        }
        
        present(alert, animated: true)
    }
    
    /// Request photo library permission for preview functionality
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                // Regardless of permission result, proceed to camera
                // User has made their choice about photo preview
                self?.proceedToCamera()
            }
        }
    }
}

extension PhotoPickTypeViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let originalImage = image as? UIImage else { return }
            DispatchQueue.main.async {
                // Use PhotoProcessor to process the image
                let processedImage = PhotoProcessor.processPhoto(originalImage)
                
                if let processedImage = processedImage {
                    // If processing succeeds, navigate to edit screen
                    let editVC = PhotoEditViewController()
                    editVC.image = processedImage
                    editVC.completion = self.completion
                    self.navigationController?.pushViewController(editVC, animated: true)
                } else {
                    SVProgressHUD.showError(withStatus: ResourceManager.L10n.Photo.formatTips)
                }
            }
        }
    }
}
