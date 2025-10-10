//
//  AgentToast.swift
//  Common
//
//  Created by Assistant on 2025/01/27.
//

import UIKit

/// Toast style enumeration
public enum ToastStyle {
    case info
    case success
    case warn
    case error
    
    var iconName: String {
        switch self {
        case .info:
            return "ic_toast_info"
        case .success:
            return "ic_toast_success"
        case .warn:
            return "ic_toast_warn"
        case .error:
            return "ic_toast_error"
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .info:
            return UIColor.themColor(named: "ai_brand_main6")
        case .success:
            return UIColor.themColor(named: "ai_green6")
        case .warn:
            return UIColor.themColor(named: "ai_yellow6")
        case .error:
            return UIColor.themColor(named: "ai_red6")
        }
    }
}

/// Toast component for displaying temporary messages
public class AgentToast: UIView {
    
    // MARK: - Properties
    private let style: ToastStyle
    private let message: String
    private let duration: TimeInterval
    private var hideTimer: Timer?
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block3")
        view.layer.cornerRadius = 8
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.ag_named(style.iconName)
        return imageView
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    // MARK: - Initialization
    private init(style: ToastStyle, message: String, duration: TimeInterval = 3.0) {
        self.style = style
        self.message = message
        self.duration = duration
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        // Disable autoresizing mask
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Container view constraints - relative to parent view (window)
        if let s = superview {
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: s.centerXAnchor),
                containerView.widthAnchor.constraint(lessThanOrEqualTo: s.widthAnchor, constant: -32),
                containerView.topAnchor.constraint(equalTo: s.topAnchor, constant: 200),
                containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
            ])
        }
        
        // Icon image view constraints
        NSLayoutConstraint.activate([
            iconImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Message label constraints
        NSLayoutConstraint.activate([
            messageLabel.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: 12),
            messageLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Public Methods
    
    /// Show toast with info style
    /// - Parameters:
    ///   - message: Message to display
    ///   - duration: Display duration in seconds
    public static func showInfo(_ message: String, duration: TimeInterval = 3.0) {
        show(style: .info, message: message, duration: duration)
    }
    
    /// Show toast with success style
    /// - Parameters:
    ///   - message: Message to display
    ///   - duration: Display duration in seconds
    public static func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(style: .success, message: message, duration: duration)
    }
    
    /// Show toast with warning style
    /// - Parameters:
    ///   - message: Message to display
    ///   - duration: Display duration in seconds
    public static func showWarn(_ message: String, duration: TimeInterval = 3.0) {
        show(style: .warn, message: message, duration: duration)
    }
    
    /// Show toast with error style
    /// - Parameters:
    ///   - message: Message to display
    ///   - duration: Display duration in seconds
    public static func showError(_ message: String, duration: TimeInterval = 3.0) {
        show(style: .error, message: message, duration: duration)
    }
    
    /// Show toast with custom style
    /// - Parameters:
    ///   - style: Toast style
    ///   - message: Message to display
    ///   - duration: Display duration in seconds
    public static func show(style: ToastStyle, message: String, duration: TimeInterval = 3.0) {
        // Hide existing toast if any
        hideExistingToast()
        
        // Create and show new toast
        let toast = AgentToast(style: style, message: message, duration: duration)
        toast.show()
    }
    
    /// Hide all existing toasts
    public static func hideAll() {
        hideExistingToast()
    }
    
    // MARK: - Private Methods
    private func show() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        
        // Add to window
        window.addSubview(self)
        setupConstraints()
        
        // Setup initial state
        self.alpha = 0
        self.transform = CGAffineTransform(translationX: 0, y: -20)
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        }
        
        // Setup auto hide timer
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    private func hide() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -20)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    private static func hideExistingToast() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        
        // Find and remove existing toast views
        for subview in window.subviews {
            if let toast = subview as? AgentToast {
                toast.hideTimer?.invalidate()
                toast.removeFromSuperview()
            }
        }
    }
    
    deinit {
        hideTimer?.invalidate()
    }
}
