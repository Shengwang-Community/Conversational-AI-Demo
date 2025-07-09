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
import AVFoundation

class PhotoPickTypeViewController: UIViewController {
    private var completion: ((UIImage?) -> Void)?
    
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

    static func start(from presentingVC: UIViewController, completion: @escaping (UIImage?) -> Void) {
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
        
        // Divider - 优化样式
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

        photoLabel.text = ResourceManager.L10n.Photo.photo
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

        cameraLabel.text = ResourceManager.L10n.Photo.camera
        cameraLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        cameraLabel.font = UIFont.systemFont(ofSize: 12)
        cameraLabel.textAlignment = .center
        cameraOptionView.addSubview(cameraLabel)
        
        // 添加点击空白处消失的手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // 添加下拉拖动消失的手势
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
            if translation.y > 60 || velocity.y > 500 { // 拖动超过60或速度超过500关闭
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
                let takeVC = TakePhotoViewController()
                takeVC.completion = self.completion
                self.navigationController?.pushViewController(takeVC, animated: true)
            } else {
                self.showPermissionAlert(for: .camera)
            }
        }
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
        case photoLibrary
        case camera
    }
    
    private func showPermissionAlert(for type: PermissionType) {
        let title: String
        let message: String
        
        switch type {
        case .photoLibrary:
            title = "Photo Access Permission"
            message = "We need access to your photo library to select images. Please enable photo access permission in Settings."
        case .camera:
            title = "Camera Access Permission"
            message = "We need access to your camera to take photos. Please enable camera access permission in Settings."
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        present(alert, animated: true)
    }
}

extension PhotoPickTypeViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let originalImage = image as? UIImage else { return }
            DispatchQueue.main.async {
                // Adjust image size to meet validation requirements
                let processedImage = self.resizeImageIfNeeded(originalImage)
                
                // Validate photo against requirements
                let validationResult = PhotoValidator.validatePhoto(processedImage)
                
                if !validationResult.isValid {
                    // Display error message for failed validation
                    let alert = UIAlertController(title: "Image Validation Failed", message: validationResult.errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                }
                
                // If validation passes, navigate to edit screen
                let editVC = PhotoEditViewController()
                editVC.image = processedImage
                editVC.completion = self.completion
                self.navigationController?.pushViewController(editVC, animated: true)
            }
        }
    }
    
    /**
     * If needed, adjust image size to meet validation requirements
     */
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048  // Keep consistent with PhotoValidator
        let originalSize = image.size
        
        // If image size is already acceptable, return directly
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            print("[PhotoPickTypeViewController] Image size is acceptable: \(originalSize.width)x\(originalSize.height)")
            return image
        }
        
        // Calculate new size, maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Width is larger, use width as reference
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Height is larger, use height as reference
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        print("[PhotoPickTypeViewController] Resizing image from \(originalSize.width)x\(originalSize.height) to \(newSize.width)x\(newSize.height)")
        
        // Create graphics context and draw the adjusted image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}
