//
//  IOTWifiConfigViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/7.
//

import UIKit
import Common
import CoreBluetooth
import BLEManager
import Network
import SVProgressHUD

class IOTWifiSettingViewController: BaseViewController {
    
    // MARK: - Properties
    var device: BLEDevice?
    private let wifiManager = WiFiManager()
    private var keyboardHeight: CGFloat = 0
    
    private lazy var segmentedControl: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_block1")
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var wifiTab: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotTabWifi, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(switchToWiFi), for: .touchUpInside)
        return button
    }()
    
    private lazy var hotspotTab: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.Iot.hotspotTabMobile, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(switchToHotspot), for: .touchUpInside)
        return button
    }()
    
    private lazy var wifiScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        return scrollView
    }()
    
    private lazy var hotspotScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.isHidden = true
        return scrollView
    }()
    
    private lazy var wifiSettingView: WifiSettingView = {
        let view = WifiSettingView()
        return view
    }()
    
    private lazy var hotspotView: HotspotView = {
        let view = HotspotView()
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupCallbacks()
        updateNextButtonState()
        setupKeyboardHandling()
        setupNotifications()
        
        // 设置初始状态
        switchToWiFi()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let currentSSID = getCurrentWiFiSSID() {
            wifiSettingView.updateWifiName(currentSSID)
        } else {
            wifiSettingView.updateWifiName("")
        }
        checkWiFiStatus { connected in
            if !connected {
                SVProgressHUD.showInfo(withStatus: "No Wi-Fi connection detected, please connect to Wi-Fi first")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupViews() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        naviBar.backgroundColor = UIColor.themColor(named: "ai_fill1")
        
        naviBar.addSubview(segmentedControl)
        segmentedControl.addSubview(wifiTab)
        segmentedControl.addSubview(hotspotTab)
        
        view.addSubview(wifiScrollView)
        view.addSubview(hotspotScrollView)
        
        wifiScrollView.addSubview(wifiSettingView)
        hotspotScrollView.addSubview(hotspotView)
        
        setupConstraints()
        view.bringSubviewToFront(naviBar)
    }
    
    private func setupConstraints() {
        segmentedControl.snp.makeConstraints { make in
            make.bottom.equalTo(naviBar.snp.bottom)
            make.centerX.equalToSuperview()
            make.width.equalTo(242)
            make.height.equalTo(42)
        }
        
        wifiTab.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview().inset(2)
            make.width.equalTo(119)
        }
        
        hotspotTab.snp.makeConstraints { make in
            make.right.top.bottom.equalToSuperview().inset(2)
            make.width.equalTo(119)
        }
        
        wifiScrollView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        hotspotScrollView.snp.makeConstraints { make in
            make.edges.equalTo(wifiScrollView)
        }
        
        wifiSettingView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.width.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        hotspotView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.width.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
        
    private func setupCallbacks() {
        hotspotView.onGoToSettings = {
            if let url = URL(string: "App-Prefs:root=INTERNET_TETHERING"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        }
        
        hotspotView.onNext = { [weak self] in
            // Handle hotspot next button tap
            guard let self = self, let device = self.device else { return }
            
            let vc = DeviceAddingViewController()
            vc.wifiName = hotspotView.deviceNameField.text ?? ""
            vc.password = hotspotView.passwordField.text ?? ""
            vc.device = device
            self.navigationController?.pushViewController(vc)
        }
        
        wifiSettingView.onSwitchNetwork = { [weak self] in
            self?.switchNetworkButtonTapped()
        }
        
        wifiSettingView.onPasswordChanged = { [weak self] text in
            self?.updateNextButtonState()
        }
        
        wifiSettingView.onPasswordVisibilityToggled = { [weak self] in
            self?.wifiSettingView.togglePasswordFieldSecureEntry()
        }
        
        wifiSettingView.onNextButtonTapped = { [weak self] in
            guard let self = self, let device = self.device else { return }
            
            let vc = DeviceAddingViewController()
            vc.wifiName = wifiSettingView.wifiNameField.text ?? ""
            vc.password = wifiSettingView.passwordField.text ?? ""
            vc.device = device
            self.navigationController?.pushViewController(vc)
        }
    }
    
    private func updateNextButtonState() {
        let password = wifiSettingView.passwordField.text ?? ""
        let hasValidPassword = password.count >= 8
        wifiSettingView.updateNextButtonState(enabled: hasValidPassword)
    }
    
    private func setupKeyboardHandling() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(keyboardWillShow),
                                             name: UIResponder.keyboardWillShowNotification,
                                             object: nil)
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(keyboardWillHide),
                                             name: UIResponder.keyboardWillHideNotification,
                                             object: nil)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(applicationDidEnterBackground),
                                             name: UIApplication.didEnterBackgroundNotification,
                                             object: nil)
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(applicationWillEnterForeground),
                                             name: UIApplication.willEnterForegroundNotification,
                                             object: nil)
    }
    
    private func getCurrentWiFiSSID() -> String? {
        var result: String? = ""
        wifiManager.getWiFiSSID { ssid in
            result = ssid
        }
        return result
    }
    
    private func checkWiFiStatus(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                monitor.cancel()
                completion(path.status == .satisfied)
            }
        }
        
        monitor.start(queue: DispatchQueue.global())
    }
    
    // MARK: - Actions
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func switchToWiFi() {
        wifiTab.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        wifiTab.setTitleColor(.white, for: .normal)
        hotspotTab.backgroundColor = .clear
        hotspotTab.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        
        wifiScrollView.isHidden = false
        hotspotScrollView.isHidden = true
    }
    
    @objc private func switchToHotspot() {
        hotspotTab.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
        hotspotTab.setTitleColor(.white, for: .normal)
        wifiTab.backgroundColor = .clear
        wifiTab.setTitleColor(UIColor.themColor(named: "ai_icontext2"), for: .normal)
        
        wifiScrollView.isHidden = true
        hotspotScrollView.isHidden = false
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let activeScrollView = wifiScrollView.isHidden ? hotspotScrollView : wifiScrollView
        let lastTextField = wifiScrollView.isHidden ? hotspotView.passwordField : wifiSettingView.passwordField
        
        let textFieldBottom = lastTextField.convert(lastTextField.bounds, to: view).maxY
        let keyboardTop = view.frame.height - keyboardHeight
        
        // Calculate overlap
        let overlap = textFieldBottom - keyboardTop + 20 // Add 20pt padding
        
        if overlap > 0 {
            let contentOffset = CGPoint(x: 0, y: overlap)
            activeScrollView.setContentOffset(contentOffset, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let activeScrollView = wifiScrollView.isHidden ? hotspotScrollView : wifiScrollView
        activeScrollView.setContentOffset(.zero, animated: true)
    }
    
    private func switchNetworkButtonTapped() {
        if let wifiUrl = URL(string: "App-Prefs:root=WIFI") {
            if UIApplication.shared.canOpenURL(wifiUrl) {
                UIApplication.shared.open(wifiUrl)
            } else {
                // Fallback to general settings if direct WiFi access is not available
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        // Handle background state if needed in the future
    }
    
    @objc private func applicationWillEnterForeground() {
        // Check WiFi SSID when app comes to foreground
        if let currentSSID = getCurrentWiFiSSID() {
            wifiSettingView.updateWifiName(currentSSID)
        } else {
            wifiSettingView.updateWifiName("")
        }
    }
}

