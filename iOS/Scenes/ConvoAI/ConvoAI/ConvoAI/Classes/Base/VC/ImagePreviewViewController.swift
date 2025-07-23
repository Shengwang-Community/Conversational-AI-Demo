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
        self.closeButton = UIButton(type: .custom)
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
        closeButton.layer.cornerRadius = 16
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
            make.size.equalTo(CGSize(width: 32, height: 32))
        }
    }
    
    private func setupGestures() {
        // Single tap to dismiss (except on close button)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        scrollView.addGestureRecognizer(tapGesture)

        // Double tap to zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.delegate = self
        scrollView.addGestureRecognizer(doubleTapGesture)

        // Make sure single tap waits for double tap to fail
        tapGesture.require(toFail: doubleTapGesture)

        // Pan to dismiss (vertical only)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        scrollView.addGestureRecognizer(panGesture)
    }

    // MARK: - Actions

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Dismiss if not tapping on the close button
        let location = gesture.location(in: view)
        if !closeButton.frame.contains(location) {
            dismiss(animated: true)
        }
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let zoomRect = CGRect(x: point.x - 50, y: point.y - 50, width: 100, height: 100)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: scrollView)
        switch gesture.state {
        case .ended:
            // Dismiss if vertical swipe is more than 80pt
            if abs(translation.y) > 80 {
                dismiss(animated: true)
            }
        default:
            break
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
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
    // Only allow tap gesture if not on close button
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer {
            let location = touch.location(in: view)
            return !closeButton.frame.contains(location)
        }
        return true
    }
    // Allow all gestures to work together
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
