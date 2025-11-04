//
//  DeveloperConfig.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/07/29.
//

import UIKit
import SnapKit
import Common

public protocol DeveloperConfigDelegate: AnyObject {
    func devConfigDidOpenDevMode(_ config: DeveloperConfig)
    func devConfigDidCloseDevMode(_ config: DeveloperConfig)
    func devConfigDidSwitchServer(_ config: DeveloperConfig)
    func devConfigDidCopy(_ config: DeveloperConfig)
    func devConfig(_ config: DeveloperConfig, sessionLimitDidChange enabled: Bool)
    func devConfig(_ config: DeveloperConfig, audioDumpDidChange enabled: Bool)
    func devConfig(_ config: DeveloperConfig, metricsDidChange enabled: Bool)
    func devConfig(_ config: DeveloperConfig, sdkParamsDidChange params: String)
}

public extension DeveloperConfigDelegate {
    func devConfigDidOpenDevMode(_ config: DeveloperConfig) {}
    func devConfigDidCloseDevMode(_ config: DeveloperConfig) {}
    func devConfigDidSwitchServer(_ config: DeveloperConfig) {}
    func devConfigDidCopy(_ config: DeveloperConfig) {}
    func devConfig(_ config: DeveloperConfig, sessionLimitDidChange enabled: Bool) {}
    func devConfig(_ config: DeveloperConfig, audioDumpDidChange enabled: Bool) {}
    func devConfig(_ config: DeveloperConfig, metricsDidChange enabled: Bool) {}
    func devConfig(_ config: DeveloperConfig, sdkParamsDidChange params: String) {}
}

public class DeveloperConfig {
    
    private let kSessionFree = "io.agora.convoai.kSessionFree"
    private let kMetrics = "io.agora.convoai.kMetrics"

    static let shared = DeveloperConfig()
    
    private var delegates = NSHashTable<AnyObject>.weakObjects()

    public func add(delegate: DeveloperConfigDelegate) {
        delegates.add(delegate)
    }

    public func remove(delegate: DeveloperConfigDelegate) {
        delegates.remove(delegate)
    }
    
    public var isDeveloperMode = false
    
    public var defaultAppId: String? = nil
    public var defaultHost: String? = nil
    public var convoaiServerConfig: String? = nil
    public var graphId: String? = nil
    public var sdkParams: [String] = []
    public var metrics: Bool = false
    public var audioDump: Bool = false
    
    public lazy var devModeButton: UIButton = {
        let button = DebugButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_setting_debug"), for: .normal)
        button.addTarget(self, action: #selector(showDevModePage), for: .touchUpInside)
        button.isHidden = true
        // Add button to window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let buttonSize: CGFloat = 44
            button.frame = CGRect(
                x: window.bounds.width - buttonSize - 16,
                y: window.bounds.height - buttonSize - 16,
                width: buttonSize,
                height: buttonSize
            )
            window.addSubview(button)
        }
        return button
    }()
    
    var clickCount = 0
    var lastClickTime: Date?
    
    public func startDevMode() {
        if isDeveloperMode {
            return
        }
        isDeveloperMode = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        devModeButton.isHidden = false
        notifyOpenDevMode()
    }
    
    public func stopDevMode() {
        if !isDeveloperMode {
            return
        }
        isDeveloperMode = false
        devModeButton.isHidden = true
        notifyCloseDevMode()
        resetDevParams()
    }
    
    @objc public func showDevModePage() {
        if let topController = topViewController() {
            DeveloperModeViewController.show(from: topController)
        }
    }
    
    public func countTouch() {
        let currentTime = Date()
        if let lastTime = lastClickTime, currentTime.timeIntervalSince(lastTime) > 1.0 {
            clickCount = 0
        }
        lastClickTime = currentTime
        clickCount += 1
        if clickCount >= 5 {
            DeveloperConfig.shared.startDevMode()
            clickCount = 0
        }
    }
    
    // MARK: - Delegate Triggers
    public func notifyOpenDevMode() {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfigDidOpenDevMode(self)
        }
    }

    public func notifyCloseDevMode() {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfigDidCloseDevMode(self)
        }
    }

    public func notifyCopy() {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfigDidCopy(self)
        }
    }

    public func notifySessionLimitChanged(enabled: Bool) {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfig(self, sessionLimitDidChange: enabled)
        }
    }

    public func notifyAudioDumpChanged(enabled: Bool) {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfig(self, audioDumpDidChange: enabled)
        }
    }

    public func notifyMetricsChanged(enabled: Bool) {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfig(self, metricsDidChange: enabled)
        }
    }

    public func notifySDKParamsChanged(params: String) {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfig(self, sdkParamsDidChange: params)
        }
    }

    public func notifySwitchServer() {
        for delegate in delegates.allObjects {
            (delegate as? DeveloperConfigDelegate)?.devConfigDidSwitchServer(self)
        }
    }

    public func setSessionLimit(_ limit: Bool) {
        UserDefaults.standard.set(!limit, forKey: kSessionFree)
    }
    
    public func getSessionLimit() -> Bool {
        return !UserDefaults.standard.bool(forKey: kSessionFree)
    }
    
    public func resetDevParams() {
        self.isDeveloperMode = false
        self.graphId = nil
        self.metrics = false
        self.sdkParams.removeAll()
        self.convoaiServerConfig = nil
        if let defaultHost = self.defaultHost {
            AppContext.shared.baseServerUrl = defaultHost
            self.defaultHost = nil
            notifySwitchServer()
        }
        
        if let defaultAppId = self.defaultAppId {
            AppContext.shared.appId = defaultAppId
            self.defaultAppId = nil
        }
    }
    
    func topViewController(_ rootViewController: UIViewController? = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.rootViewController) -> UIViewController? {
        if let presented = rootViewController?.presentedViewController {
            return topViewController(presented)
        }
        if let navigationController = rootViewController as? UINavigationController {
            return topViewController(navigationController.visibleViewController)
        }
        if let tabBarController = rootViewController as? UITabBarController {
            return topViewController(tabBarController.selectedViewController)
        }
        return rootViewController
    }
}

// MARK: - DebugButton
private class DebugButton: UIButton {
    private var lastLocation: CGPoint = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPanGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanGesture()
    }
    
    private func setupPanGesture() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panRecognizer)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        
        if recognizer.state == .began {
            lastLocation = self.center
        }
        
        let translation = recognizer.translation(in: superview)
        
        var newCenter = CGPoint(
            x: lastLocation.x + translation.x,
            y: lastLocation.y + translation.y
        )
        
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let padding: CGFloat = 16
        
        // Keep within superview bounds
        newCenter.x = max(halfWidth + padding, min(newCenter.x, superview.bounds.width - halfWidth - padding))
        newCenter.y = max(halfHeight + padding, min(newCenter.y, superview.bounds.height - halfHeight - padding))
        
        center = newCenter
        
        if recognizer.state == .ended {
            // Snap to nearest left or right edge after drag ends
            let distanceToLeft = newCenter.x - (halfWidth + padding)
            let distanceToRight = superview.bounds.width - (newCenter.x + halfWidth + padding)
            
            UIView.animate(withDuration: 0.2) {
                if distanceToLeft < distanceToRight {
                    // Snap to left edge
                    self.center.x = halfWidth + padding
                } else {
                    // Snap to right edge
                    self.center.x = superview.bounds.width - (halfWidth + padding)
                }
                self.lastLocation = self.center
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        lastLocation = self.center
    }
}
