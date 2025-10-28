//
//  SIPAreaCodeViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/10/13.
//

import UIKit
import Common
import SnapKit

class SIPAreaCodeViewController: UIViewController {
    
    // MARK: - Public Methods
    /// Present the area code selector from a view controller
    /// - Parameters:
    ///   - viewController: The view controller to present from
    ///   - completion: Callback when a vendor is selected
    static func show(from viewController: UIViewController, completion: ((VendorCalleeNumber) -> Void)? = nil) {
        let areaCodeVC = SIPAreaCodeViewController()
        areaCodeVC.onVendorSelected = completion
        areaCodeVC.modalPresentationStyle = .overFullScreen
        areaCodeVC.modalTransitionStyle = .crossDissolve
        
        viewController.present(areaCodeVC, animated: true)
    }
    
    var onVendorSelected: ((VendorCalleeNumber) -> Void)?
    private var allVendors: [VendorCalleeNumber] = []
    private var filteredVendors: [VendorCalleeNumber] = []
    private let containerHeight: CGFloat = UIScreen.main.bounds.height - 150
    private var initialCenter: CGPoint = .zero
    private var currentSearchText: String = ""
        
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()
    
    private lazy var dragIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#404548")
        view.layer.cornerRadius = 2
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_close_small"), for: .normal)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var searchContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill5")
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        return view
    }()
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = ResourceManager.L10n.Sip.areaCodeSearchPlaceholder
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = .clear
            textField.textColor = UIColor.themColor(named: "ai_icontext1")
            textField.font = UIFont.systemFont(ofSize: 14)
            textField.borderStyle = .none
            
            if let searchIcon = UIImage.ag_named("ic_agent_bar_search") {
                let iconView = UIImageView(image: searchIcon)
                iconView.contentMode = .left
                textField.leftView = iconView
                textField.leftViewMode = .always
            }
        }
        return searchBar
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = true
        table.register(AreaCodeCell.self, forCellReuseIdentifier: "AreaCodeCell")
        table.keyboardDismissMode = .onDrag
        return table
    }()
    
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.isHidden = true
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupPanGesture()
        loadRegions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        animateContainerViewIn()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        
        // Add tap gesture to dismiss on background tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Add tap gesture to container view to dismiss keyboard
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleContainerTap(_:)))
        containerTapGesture.delegate = self
        containerView.addGestureRecognizer(containerTapGesture)
        
        view.addSubview(containerView)
        containerView.addSubview(dragIndicator)
        containerView.addSubview(closeButton)
        containerView.addSubview(searchContainerView)
        searchContainerView.addSubview(searchBar)
        containerView.addSubview(tableView)
        containerView.addSubview(emptyStateView)
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(containerHeight)
        }
        
        dragIndicator.snp.makeConstraints { make in
            make.top.equalTo(8)
            make.centerX.equalToSuperview()
            make.width.equalTo(36)
            make.height.equalTo(4)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(dragIndicator.snp.bottom)
            make.right.equalTo(-16)
            make.width.height.equalTo(36)
        }
        
        searchContainerView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(8)
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.height.equalTo(36)
        }
        
        searchBar.snp.makeConstraints { make in
            make.top.bottom.left.right.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchContainerView.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
        
        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(searchContainerView.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    private func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        containerView.addGestureRecognizer(panGesture)
    }
    
    private func animateContainerViewIn() {
        containerView.transform = CGAffineTransform(translationX: 0, y: containerHeight)
        UIView.animate(withDuration: 0.3) {
            self.containerView.transform = .identity
        }
    }
    
    private func animateContainerViewOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.containerHeight)
        }) { _ in
            completion?()
            self.dismiss(animated: false)
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            initialCenter = containerView.center
        case .changed:
            let newY = max(translation.y, 0)
            containerView.transform = CGAffineTransform(translationX: 0, y: newY)
        case .ended:
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = translation.y > containerHeight / 2 || velocity.y > 500
            
            if shouldDismiss {
                animateContainerViewOut()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.containerView.transform = .identity
                }
            }
        default:
            break
        }
    }
    
    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        animateContainerViewOut()
    }
    
    @objc private func handleContainerTap(_ gesture: UITapGestureRecognizer) {
        // Dismiss keyboard when tapping on container view
        view.endEditing(true)
    }
    
    @objc private func closeButtonTapped() {
        animateContainerViewOut()
    }
    
    private func loadRegions() {
        // Directly load from preset data
        if let vendors = AppContext.settingManager().preset?.sipVendorCalleeNumbers {
            allVendors = vendors
            filteredVendors = allVendors
        }
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        let isEmpty = filteredVendors.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
}

// MARK: - UITableViewDataSource
extension SIPAreaCodeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredVendors.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AreaCodeCell", for: indexPath) as! AreaCodeCell
        let vendor = filteredVendors[indexPath.row]
        cell.configure(with: vendor, searchText: currentSearchText)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SIPAreaCodeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vendor = filteredVendors[indexPath.row]
        
        // Call the completion callback and dismiss
        animateContainerViewOut { [weak self] in
            self?.onVendorSelected?(vendor)
        }
    }
}

// MARK: - UISearchBarDelegate
extension SIPAreaCodeViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentSearchText = searchText
        if searchText.isEmpty {
            filteredVendors = allVendors
        } else {
            filteredVendors = allVendors.filter { vendor in
                let regionName = vendor.regionName ?? ""
                let regionCode = vendor.regionCode ?? ""
                return regionName.lowercased().contains(searchText.lowercased()) ||
                       regionCode.contains(searchText)
            }
        }
        tableView.reloadData()
        updateEmptyState()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Change border color to ai_brand_main6 when editing begins
        searchContainerView.layer.borderColor = UIColor.themColor(named: "ai_brand_main6").cgColor
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        // Change border color back to ai_line1 when editing ends
        searchContainerView.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SIPAreaCodeViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer.view == view {
            return touch.view == view
        }
        if gestureRecognizer.view == containerView {
            return touch.view == containerView
        }
        return true
    }
}

// MARK: - Area Code Cell
class AreaCodeCell: UITableViewCell {
    
    private lazy var flagLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 28)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var regionNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var regionCodeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.textAlignment = .right
        return label
    }()
    
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_line1")
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.themColor(named: "ai_fill2")
        
        contentView.addSubview(flagLabel)
        contentView.addSubview(regionNameLabel)
        contentView.addSubview(regionCodeLabel)
        contentView.addSubview(separatorLine)
        
        flagLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }
        
        regionNameLabel.snp.makeConstraints { make in
            make.left.equalTo(flagLabel.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }
        
        regionCodeLabel.snp.makeConstraints { make in
            make.left.equalTo(regionNameLabel.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }
        
        separatorLine.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func configure(with vendor: VendorCalleeNumber, searchText: String = "") {
        flagLabel.text = vendor.flagEmoji ?? "🏳️"
        
        let regionName = vendor.regionName ?? ""
        let regionCode = vendor.regionCode ?? ""
        
        // Apply highlighting to region name and code
        if !searchText.isEmpty {
            regionNameLabel.attributedText = highlightText(
                regionName,
                searchText: searchText,
                defaultColor: UIColor.themColor(named: "ai_icontext1"),
                font: UIFont.systemFont(ofSize: 16, weight: .medium)
            )
            regionCodeLabel.attributedText = highlightText(
                regionCode,
                searchText: searchText,
                defaultColor: UIColor.themColor(named: "ai_icontext2"),
                font: UIFont.systemFont(ofSize: 16)
            )
        } else {
            regionNameLabel.text = regionName
            regionCodeLabel.text = regionCode
        }
    }
    
    private func highlightText(_ text: String, searchText: String, defaultColor: UIColor, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Set default attributes
        attributedString.addAttributes([
            .foregroundColor: defaultColor,
            .font: font
        ], range: NSRange(location: 0, length: text.count))
        
        // Find and highlight search text
        let lowercasedText = text.lowercased()
        let lowercasedSearchText = searchText.lowercased()
        
        var searchRange = lowercasedText.startIndex..<lowercasedText.endIndex
        while let range = lowercasedText.range(of: lowercasedSearchText, range: searchRange) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.foregroundColor,
                                         value: UIColor.themColor(named: "ai_brand_main6"),
                                         range: nsRange)
            searchRange = range.upperBound..<lowercasedText.endIndex
        }
        
        return attributedString
    }
}

// MARK: - Empty State View
class EmptyStateView: UIView {
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_empty_state_loading_failed")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.Sip.areaCodeNoResults
        label.textColor = UIColor.themColor(named: "ai_icontext2")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(imageView)
        addSubview(label)
        
        imageView.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
    }
}

