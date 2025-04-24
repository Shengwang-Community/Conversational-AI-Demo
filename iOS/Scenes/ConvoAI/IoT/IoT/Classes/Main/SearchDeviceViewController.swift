//
//  SearchDeviceViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/5.
//

import Foundation
import Common
import CoreBluetooth
import BLEManager
import SVProgressHUD

class SearchDeviceViewController: BaseViewController {
    private lazy var bluetoothManager: AIBLEManager = {
        let manager = AIBLEManager.shared
        return manager
    }()
    
    private lazy var searchingView:SearchingView = {
        let rippleView = SearchingView(frame: CGRectMake(0, naviBar.height, view.bounds.width, view.bounds.height - naviBar.height))
        rippleView.delegate = self
        return rippleView
    }()
    
    private lazy var searchFailedView: DeviceSearchFailedView = {
        let view = DeviceSearchFailedView()
        view.delegate = self
        return view
    }()
    
    // Add container view
    private lazy var tableContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        
        let maskLayer = CAGradientLayer()
        maskLayer.colors = [
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 0.85, 1.0]
        view.layer.mask = maskLayer
        
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = 90
        return tableView
    }()
        
    private var devices: [BLEDevice] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        startSearchDevice()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bluetoothManager.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bluetoothManager.delegate = nil
        bluetoothManager.stopScan()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let maskLayer = tableContainer.layer.mask as? CAGradientLayer {
            maskLayer.frame = tableContainer.bounds
        }
    }
    
    private func startSearchDevice() {
        bluetoothManager.deviceConnectTimeout = 10
        bluetoothManager.startScan()
    }
    
    private func setupViews() {
        navigationTitle = ResourceManager.L10n.Iot.deviceSearchTitle
        naviBar.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.clipsToBounds = true
        
        [searchingView, tableContainer, searchFailedView].forEach { view.addSubview($0) }
        tableContainer.addSubview(tableView)
        
        searchingView.startSearch()
        searchFailedView.isHidden = true
    }
    
    private func setupConstraints() {
        tableContainer.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.bottom.equalTo(0)
        }
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        searchFailedView.snp.makeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.bottom.equalTo(0)
        }
    }
    
    private func remakeConstraints() {
        tableContainer.snp.remakeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.equalTo(0)
            make.bottom.equalTo(-200)
        }
    }
    
    private func restoreConstraints() {
        tableContainer.snp.remakeConstraints { make in
            make.top.equalTo(naviBar.snp.bottom)
            make.left.right.bottom.equalTo(0)
        }
    }
    
    private func showWifiAlert() {
        let permissions = [
            PermissionAlertViewController.Permission(
                icon: UIImage.ag_named("ic_iot_wifi_white_icon"),
                iconBackgroundColor: UIColor.themColor(named: "ai_brand_white2"),
                cardBackgroundColor: UIColor.themColor(named: "ai_green6"),
                title: ResourceManager.L10n.Iot.permissionItemWifi,
                action: {
                    // Open Location Settings
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            )
        ]

        let alertVC = PermissionAlertViewController(
            title: ResourceManager.L10n.Iot.permissionTitle,
            description: ResourceManager.L10n.Iot.permissionDescription,
            permissions: permissions
        )
        present(alertVC, animated: false)
    }
}

extension SearchDeviceViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        let index = indexPath.row
        let device = devices[index]
        cell.configData(device: device)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = self.devices[indexPath.row]
        let vc = IOTWifiSettingViewController()
        vc.device = device
        self.navigationController?.pushViewController(vc)
    }
}

extension SearchDeviceViewController: SearchingViewDelegate, DeviceSearchFailedViewDelegate {
    func searchTimeout() {
        bluetoothManager.stopScan()
        let noResult = devices.isEmpty
        if noResult {
            searchFailedView.isHidden = false
            searchingView.isHidden = true
        } else {
            searchFailedView.isHidden = true
            searchingView.isHidden = true
        }
        restoreConstraints()
    }
    
    func researchCallback() {
        searchFailedView.isHidden = true
        searchingView.isHidden = false
        searchingView.startSearch()
        bluetoothManager.startScan()
    }
}

extension SearchDeviceViewController: BLEManagerDelegate {
    func bleManagerOnDevicConfigStateChanged(manager: AIBLEManager, oldState: AIBLEManager.DeviceConfigState, newState: AIBLEManager.DeviceConfigState) {
        addLog("[Call] bleManagerOnDevicConfigStateChanged old: \(oldState), new: \(newState)")
        switch newState {
        case .readyToScanDevices:
            bluetoothManager.startScan()
        case .deviceConnected:
            addLog("device connnected")
        case .wifiConfiguration:
            print("show load...")
        case .wifiConfigurationDone:
            print("dismiss load...")
        default:
            print("state = \(newState)")
        }
    }
    
    func bleManagerOnLastLogInfo(manager: AIBLEManager, logInfo: String) {
        addLog("[Call] bleManagerOnLastLogInfo : \(logInfo)")
    }
    
    func bleManagerDidScanDevice(_ manager: AIBLEManager, device: BLEDevice, error: Error?) {
        if let data = device.data[CBAdvertisementDataManufacturerDataKey] as? Data {
//            if bluetoothManager.bekenDeviceManufacturerData == data {
            let prefixName = device.name.prefix(3)
            if prefixName == "X1-", !devices.contains(where: { $0.id == device.id }) {
                    if devices.isEmpty {
                        remakeConstraints()
                        searchingView.hideTextView(isHidden: true)
                        searchingView.alpha = 0.5
                    }
                    devices.append(device)
                    tableView.reloadData()
                }
            }
//        }
    }
}
