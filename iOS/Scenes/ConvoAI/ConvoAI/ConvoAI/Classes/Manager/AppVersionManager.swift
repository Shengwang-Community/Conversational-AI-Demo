//
//  AppVersionManager.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2026/1/19.
//

import Foundation
import UIKit
import Common
import SnapKit

public enum VersionCheckResult {
    case isDebugBuild
    case needsUpdate(latestVersion: String, downloadUrl: String)
    case upToDate
}

public class AppVersionManager {
    
    private let toolBoxApiManager = ToolBoxApiManager()
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Check version and handle result automatically (add dev tag or show update alert)
    public func checkVersionAndHandle() {
        checkVersion { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .isDebugBuild:
                self.addGlobalDevTag()
            case .needsUpdate(let latestVersion, let downloadUrl):
                self.showUpdateAlert(latestVersion: latestVersion, downloadUrl: downloadUrl)
            case .upToDate:
                ConvoAILogger.info("[Version] App is up to date")
            }
        }
    }
    
    /// Check version update
    /// - Parameter completion: Version check result callback
    public func checkVersion(completion: @escaping (VersionCheckResult) -> Void) {
        // Check bundle name first: if it's a test package, return directly without requesting API
        if !isReleaseBuild() {
            completion(.isDebugBuild)
            return
        }
        
        // Release build: request latest version number
        ConvoAILogger.info("[Version] Requesting latest version")
        toolBoxApiManager.getLatestDemoVersion { [weak self] response in
            guard let self = self else { return }
            ConvoAILogger.info("[Version] Latest version response: \(response)")
            // Check response status code
            let code = response["code"] as? Int ?? -1
            guard code == 0 else {
                // API returned error, default to up-to-date
                completion(.upToDate)
                return
            }
            
            // Parse data
            guard let data = response["data"] as? [String: Any],
                  let iosData = data["ios"] as? [String: Any] else {
                // Data format error, default to up-to-date
                completion(.upToDate)
                return
            }
            
            let latestAppVersion = (iosData["app_version"] as? String ?? "").replacingOccurrences(of: "v", with: "")
            let latestBuildVersion = Int(iosData["build_version"] as? String ?? "0") ?? 0
            let downloadUrl = iosData["download_url"] as? String ?? ""
            
            // Check if it's the latest version
            // Compare app_version first, then build_version if app_version is the same
            let isLatestVersion = !self.isVersionOlder(latestAppVersion: latestAppVersion, latestBuildVersion: latestBuildVersion)
            
            if isLatestVersion {
                // Release build and is latest version
                completion(.upToDate)
            } else {
                // Release build but not latest version
                // If download URL is empty, don't show update alert
                if downloadUrl.isEmpty {
                    completion(.upToDate)
                } else {
                    completion(.needsUpdate(latestVersion: latestAppVersion, downloadUrl: downloadUrl))
                }
            }
        } failure: { error in
            // Network request failed, release build defaults to up-to-date
            completion(.upToDate)
        }
    }
    
    /// Get current app Bundle Identifier
    public func getBundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? ""
    }
    
    /// Get current app version number
    public func getCurrentVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    /// Get current app build version number
    public func getCurrentBuildVersion() -> Int {
        let buildVersionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return Int(buildVersionString) ?? 0
    }
    
    // MARK: - Private Methods
    
    /// Check if it's a release build
    /// - Returns: true means release build, false means test build
    private func isReleaseBuild() -> Bool {
        // Check if bundle name contains "test"
        let bundleId = getBundleIdentifier().lowercased()
        return !bundleId.contains("test")
    }
    
    /// Check if current version is older than the latest version
    /// - Parameters:
    ///   - latestAppVersion: Latest app version (e.g., "2.0.1")
    ///   - latestBuildVersion: Latest build version (e.g., 2026011201)
    /// - Returns: true means current version is older and needs update
    private func isVersionOlder(latestAppVersion: String, latestBuildVersion: Int) -> Bool {
        // Get current versions
        let currentAppVersion = getCurrentVersion()
        let currentBuildVersion = getCurrentBuildVersion()
        
        // Compare app version first
        let currentComponents = currentAppVersion.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latestAppVersion.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxLength {
            let current = i < currentComponents.count ? currentComponents[i] : 0
            let latest = i < latestComponents.count ? latestComponents[i] : 0
            
            if current < latest {
                // Current app version is older
                return true
            } else if current > latest {
                // Current app version is newer
                return false
            }
        }
        
        // App versions are the same, compare build version
        return currentBuildVersion < latestBuildVersion
    }
    
    /// Add global dev tag to window (for debug builds)
    public func addGlobalDevTag() {
        guard let window = UIApplication.kWindow else {
            return
        }
        let devTag = UILabel()
        devTag.text = "TEST"
        devTag.textColor = .black
        // #446CFF99: RGB = #446CFF, Alpha = 0x99 (153/255 ≈ 0.6)
        devTag.backgroundColor = UIColor(hex: "#446CFF", alpha: 153.0 / 255.0)
        devTag.font = UIFont.boldSystemFont(ofSize: 20)
        devTag.textAlignment = .center
        
        window.addSubview(devTag)
        devTag.snp.makeConstraints { make in
            make.width.equalTo(120)
            make.height.equalTo(40)
            make.top.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(30)
        }
        
        // Rotate 45 degrees clockwise after constraints are set
        devTag.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 4)
        window.bringSubviewToFront(devTag)
    }
}

// MARK: - Version Update Alert Helper

extension AppVersionManager {
    
    /// Show version update alert
    /// - Parameters:
    ///   - latestVersion: Latest version number
    ///   - downloadUrl: Download URL
    public func showUpdateAlert(latestVersion: String,
                                downloadUrl: String) {
        let currentVersion = getCurrentVersion()
        let versionInfo = String(format: ResourceManager.L10n.Main.updateAlertVersionInfo, currentVersion, latestVersion)
        
        VersionUpdateAlertView.show(
            title: ResourceManager.L10n.Main.updateAlertTitle,
            versionInfo: versionInfo,
            description: ResourceManager.L10n.Main.updateAlertDescription,
            updateTitle: ResourceManager.L10n.Main.updateAlertUpdateButton,
            laterText: ResourceManager.L10n.Main.updateAlertLaterText,
            onUpdate: {
                // Navigate to download URL
                var urlString = downloadUrl
                // Add protocol prefix if missing
                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                    urlString = "https://" + urlString
                }
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            },
            onLater: nil
        )
    }
}

// MARK: - VersionUpdateAlertView

private class VersionUpdateAlertView: UIView {
    
    // MARK: - Properties
    
    var onUpdateButtonTapped: (() -> Void)?
    var onLaterTapped: (() -> Void)?
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_mask1")
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    // Top image section
    private lazy var topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.ag_named("img_app_update")
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    // Bottom content section with dark background
    private lazy var contentView: UIView = {
        let view = UIView()
        // Use dark background for content area
        view.backgroundColor = UIColor.themColor(named: "ai_block2")
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var versionInfoLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var updateButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitleColor(UIColor.themColor(named: "ai_brand_white10"), for: .normal)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(updateButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var laterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        button.addTarget(self, action: #selector(laterButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(backgroundView)
        addSubview(containerView)
        
        containerView.addSubview(topImageView)
        containerView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(versionInfoLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(updateButton)
        contentView.addSubview(laterButton)
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(315)
        }
        
        topImageView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.top.equalTo(topImageView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }
        
        versionInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(versionInfoLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }
        
        updateButton.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.height.equalTo(44)
        }
        
        laterButton.snp.makeConstraints { make in
            make.top.equalTo(updateButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    // MARK: - Public Methods
    
    static func show(
        title: String,
        versionInfo: String,
        description: String,
        updateTitle: String,
        laterText: String,
        onUpdate: (() -> Void)? = nil,
        onLater: (() -> Void)? = nil
    ) {
        // Find the key window
        guard let window = UIApplication.kWindow else {
            return
        }
        
        let alertView = VersionUpdateAlertView(frame: window.bounds)
        alertView.onUpdateButtonTapped = onUpdate
        alertView.onLaterTapped = onLater
        alertView.configureContent(title: title, versionInfo: versionInfo, description: description, updateTitle: updateTitle, laterText: laterText)
        
        // Add to window
        window.addSubview(alertView)
        
        // Animate in
        alertView.containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        alertView.containerView.alpha = 0
        alertView.backgroundView.alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            alertView.containerView.transform = .identity
            alertView.containerView.alpha = 1
            alertView.backgroundView.alpha = 1
        }
    }
    
    private func configureContent(title: String, versionInfo: String, description: String, updateTitle: String, laterText: String) {
        titleLabel.text = title
        versionInfoLabel.text = versionInfo
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: description, attributes: attributes)
        descriptionLabel.attributedText = attributedString
        
        updateButton.setTitle(updateTitle, for: .normal)
        laterButton.setTitle(laterText, for: .normal)
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.containerView.alpha = 0
            self.backgroundView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    @objc private func laterButtonTapped() {
        dismiss { [weak self] in
            self?.onLaterTapped?()
        }
    }
    
    @objc private func updateButtonTapped() {
        dismiss { [weak self] in
            self?.onUpdateButtonTapped?()
        }
    }
}
