//
//  PhotoEditViewController.swift
//  AgoraEntScenarios
//
//  Created by HeZhengQing on 2025/07/03.
//

import UIKit
import SnapKit
import Common

class PhotoEditViewController: UIViewController {
    var image: UIImage?
    var completion: ((PhotoResult?) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .custom)
    private let doneButton = UIButton(type: .system)
    
    private let topBar = UIView()
    private let bottomBar = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        createViews()
        createConstraints()
        setupZoom()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func setupZoom() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoomRect = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    @objc func doneAction() {
        guard let finalImage = imageView.image else {
            completion?(nil)
            dismiss(animated: true)
            return
        }
        
        // Save image and generate result in background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let photoResult = try self?.saveImageAndCreateResult(finalImage)
                DispatchQueue.main.async {
                    self?.completion?(photoResult)
                    self?.dismiss(animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    print("Failed to save photo: \(error.localizedDescription)")
                    self?.completion?(nil)
                    self?.dismiss(animated: true)
                }
            }
        }
    }
    
    /**
     * Get app-specific photo output directory
     */
    private func getPhotoOutputDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("edited_photos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        return photosDirectory
    }
    
    /**
     * Generate unique photo file name
     */
    private func generatePhotoFileName() -> String {
        return "photo_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    }
    
    /**
     * Save UIImage to file and create PhotoResult object
     */
    private func saveImageAndCreateResult(_ image: UIImage) throws -> PhotoResult {
        let photoDirectory = getPhotoOutputDirectory()
        let fileName = generatePhotoFileName()
        let fileURL = photoDirectory.appendingPathComponent(fileName)
        
        // Convert UIImage to JPEG data and save
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "PhotoEditError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert image data"])
        }
        
        try imageData.write(to: fileURL)
        
        // Create and return PhotoResult object
        return PhotoResult(
            image: image,
            filePath: fileURL.path,
            fileURL: fileURL
        )
    }

    @objc func backAction() {
        navigationController?.popViewController(animated: true)
    }

    @objc func rotateAction() {
        guard let currentImage = imageView.image else { return }
        guard let rotatedImage = currentImage.rotateCounterclockwise() else { return }
        scrollView.setZoomScale(1.0, animated: false)
        self.imageView.image = rotatedImage
    }
}

extension PhotoEditViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        bounceBackIfNeeded()
    }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        bounceBackIfNeeded()
    }
    private func bounceBackIfNeeded() {
        UIView.animate(withDuration: 0.3) {
            self.scrollView.setZoomScale(max(1.0, min(self.scrollView.zoomScale, 3.0)), animated: false)
        }
    }
}

private extension UIImage {
    func rotate(radians: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let transform = CGAffineTransform(rotationAngle: radians)
        var rect = CGRect(origin: .zero, size: self.size).applying(transform)
        rect.origin = .zero
        UIGraphicsBeginImageContext(rect.size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: rect.size.width/2, y: rect.size.height/2)
        context.rotate(by: radians)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    func rotateCounterclockwise() -> UIImage? {
        return rotate(radians: -.pi/2)
    }
}

// MARK: - Creation
extension PhotoEditViewController {
    private func createViews() {
        // ScrollView for zooming
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        // ImageView for preview
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        
        topBar.backgroundColor = UIColor.themColor(named: "ai_brand_black10")
        view.addSubview(topBar)
        
        bottomBar.backgroundColor = UIColor.themColor(named: "ai_brand_black10")
        view.addSubview(bottomBar)

        // Close button
        closeButton.setImage(UIImage.ag_named("ic_agent_setting_close"), for: .normal)
        closeButton.tintColor = UIColor.themColor(named: "ai_brand_white10")
        closeButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)
        topBar.addSubview(closeButton)

        // Rotate button
        rotateButton.setImage(UIImage.ag_named("ic_photo_preivew_rotate"), for: .normal)
        rotateButton.tintColor = UIColor.themColor(named: "ai_brand_white10")
        rotateButton.backgroundColor = UIColor.themColor(named: "ai_brand_white1")
        rotateButton.addTarget(self, action: #selector(rotateAction), for: .touchUpInside)
        rotateButton.layer.cornerRadius = 8
        rotateButton.layer.masksToBounds = true
        bottomBar.addSubview(rotateButton)

        // Done button
        doneButton.setTitle(ResourceManager.L10n.Photo.done, for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        doneButton.setTitleColor(UIColor.themColor(named: "ai_brand_black10"), for: .normal)
        doneButton.backgroundColor = UIColor.themColor(named: "ai_brand_white10")
        doneButton.layer.cornerRadius = 8
        doneButton.layer.masksToBounds = true
        doneButton.addTarget(self, action: #selector(doneAction), for: .touchUpInside)
        bottomBar.addSubview(doneButton)
    }

    private func createConstraints() {
        topBar.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(66)
        }
        
        bottomBar.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(170)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
            make.left.right.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(scrollView)
        }
        closeButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        rotateButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(38)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        doneButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-38)
            make.centerY.equalToSuperview()
            make.width.equalTo(78)
            make.height.equalTo(36)
        }
    }
}
