//
//  PhotoEditViewController.swift
//  AgoraEntScenarios
//
//  Created by HeZhengQing on 2025/07/03.
//

import UIKit
import SnapKit

class PhotoEditViewController: UIViewController {
    var image: UIImage?
    private var completion: ((Data?) -> Void)?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .custom)
    private let doneButton = UIButton(type: .system)
    private var currentRotation: CGFloat = 0

    // 展示入口类方法
    static func show(from presentingVC: UIViewController, with image: UIImage, completion: @escaping (Data?) -> Void) {
        let editVC = PhotoEditViewController()
        editVC.image = image
        editVC.completion = completion
        presentingVC.present(editVC, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        createViews()
        createConstraints()
        setupZoom()
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
        // 完成编辑后的处理
        let rotatedImage = imageView.image?.rotate(radians: currentRotation)
        let imageData = rotatedImage?.jpegData(compressionQuality: 0.9)
        completion?(imageData)
        dismiss(animated: true)
    }

    @objc func backAction() {
        completion?(nil)
        dismiss(animated: true)
    }

    @objc func rotateAction() {
        currentRotation += .pi/2
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

        // Close button
        closeButton.setImage(UIImage.ag_named("ic_close"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)
        view.addSubview(closeButton)

        // Rotate button
        rotateButton.setImage(UIImage.ag_named("ic_photo_preivew_rotate"), for: .normal)
        rotateButton.tintColor = .white
        rotateButton.addTarget(self, action: #selector(rotateAction), for: .touchUpInside)
        view.addSubview(rotateButton)

        // Done button
        doneButton.setTitle("完成", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.backgroundColor = .white.withAlphaComponent(0.1)
        doneButton.layer.cornerRadius = 8
        doneButton.addTarget(self, action: #selector(doneAction), for: .touchUpInside)
        view.addSubview(doneButton)
    }

    private func createConstraints() {
        scrollView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
            make.height.equalTo(scrollView)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(32)
        }
        rotateButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(32)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
            make.width.height.equalTo(48)
        }
        doneButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-32)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
            make.width.equalTo(72)
            make.height.equalTo(40)
        }
    }
}
