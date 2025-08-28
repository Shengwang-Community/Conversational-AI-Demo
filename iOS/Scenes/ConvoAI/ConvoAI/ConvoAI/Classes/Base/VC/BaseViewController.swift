//
//  BaseViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/4.
//

import UIKit

class BaseViewController: UIViewController {
    let naviBar = NavigationBar()
    
    var navigationTitle: String? {
        didSet {
            naviBar.title = navigationTitle
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        configCustomNaviBar()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clean up when view is about to disappear
        if isMovingFromParent || isBeingDismissed {
            viewWillDisappearAndPop()
        }
    }
    
    private func configCustomNaviBar() {
        naviBar.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.addSubview(naviBar)
        
        // Hide system navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Setup back button if not root view controller
        if navigationController?.viewControllers.count ?? 0 > 1 {
            naviBar.setLeftButtonTarget(
                self,
                action: #selector(navigationBackButtonTapped),
                image: UIImage.ag_named("ic_agora_back")
            )
        }
        
        // Configure interactive pop gesture recognizer
        configurePopGestureRecognizer()
    }
    
    func addLog(_ txt: String) {
        ConvoAILogger.info(txt)
    }
    
    @objc func navigationBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func navigationRightButtonTapped() {}
    
    // MARK: - Pop Gesture Configuration
    private func configurePopGestureRecognizer() {
        // Enable interactive pop gesture recognizer even when navigation bar is hidden
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    // MARK: - Override Methods for Subclasses
    /// Override this method to customize pop gesture behavior
    func shouldEnablePopGesture() -> Bool {
        return true
    }
    
    /// Override this method to handle custom logic when pop gesture begins
    func popGestureWillBegin() {
        // Default implementation does nothing
    }
    
    /// Override this method to handle cleanup when view controller is about to be popped
    func viewWillDisappearAndPop() {
        // Default implementation does nothing
    }
}

// MARK: - UIGestureRecognizerDelegate
extension BaseViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Check if this is the pop gesture recognizer
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            // Only allow pop gesture if there are more than one view controller in the stack
            let shouldBegin = navigationController?.viewControllers.count ?? 0 > 1 && shouldEnablePopGesture()
            
            if shouldBegin {
                popGestureWillBegin()
            }
            
            return shouldBegin
        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition with other gesture recognizers
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Ensure pop gesture has priority over other gestures
        return true
    }
}
