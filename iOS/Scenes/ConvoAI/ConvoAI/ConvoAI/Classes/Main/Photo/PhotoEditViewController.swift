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
    var completion: ((UIImage?) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .custom)
    private let doneButton = UIButton(type: .system)
    private var currentRotation: CGFloat = 0
    
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
        let rotatedImage = imageView.image?.rotate(radians: currentRotation)
        completion?(rotatedImage)
        dismiss(animated: true)
    }

    @objc func backAction() {
        navigationController?.popViewController(animated: true)
    }

    @objc func rotateAction() {
        currentRotation -= .pi/2
        UIView.animate(withDuration: 0.25) {
            self.imageView.transform = CGAffineTransform(rotationAngle: self.currentRotation)
        }
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
