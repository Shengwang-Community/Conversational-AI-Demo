//
//  ImagePreviewViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/15.
//

import Foundation
import UIKit
import SnapKit

// MARK: - ImagePreviewViewController
class ImagePreviewViewController: UIViewController {
    private let imageView: UIImageView
    private let scrollView: UIScrollView
    private let closeButton: UIButton
    
    init(image: UIImage) {
        self.scrollView = UIScrollView()
        self.imageView = UIImageView(image: image)
        self.closeButton = UIButton(type: .system)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupGestures()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        
        // Setup scroll view
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        
        // Setup close button
        closeButton.setImage(UIImage.ag_named("ic_preview_close_icon"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(closeButton)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
            make.height.equalTo(scrollView)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.equalToSuperview().offset(16)
            make.size.equalTo(CGSize(width: 44, height: 44))
        }
    }
    
    private func setupGestures() {
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Add double tap gesture to zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // Make sure single tap doesn't interfere with double tap
        tapGesture.require(toFail: doubleTapGesture)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func backgroundTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale == scrollView.minimumZoomScale {
            // Zoom in
            let location = gesture.location(in: imageView)
            let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
            scrollView.zoom(to: rect, animated: true)
        } else {
            // Zoom out
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - UIScrollViewDelegate
extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Center the image when zoomed
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, 
                                  y: scrollView.contentSize.height * 0.5 + offsetY)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ImagePreviewViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only allow tap gesture on the background (not on the close button)
        return touch.view == view
    }
}
