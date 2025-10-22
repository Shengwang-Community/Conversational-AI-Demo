//
//  SIPPhoneListView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common

// MARK: - Phone List Style Configuration
enum SIPPhoneListStyle {
    case global
    case inland
}

// MARK: - Delegate Protocol
protocol SIPPhoneListViewDelegate: AnyObject {
    func sipPhoneListView(_ listView: SIPPhoneListView, didSelectVendor vendor: VendorCalleeNumber, at index: Int)
}

class SIPPhoneListView: UIView {
    
    // MARK: - Delegate
    weak var delegate: SIPPhoneListViewDelegate?
    
    // MARK: - Properties
    private let listStyle: SIPPhoneListStyle
    
    private lazy var singleItemView: SinglePhoneNumberView = {
        let view = SinglePhoneNumberView(style: listStyle)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(singleItemViewTapped))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = UIColor.clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = true
        table.register(PhoneNumberCell.self, forCellReuseIdentifier: "PhoneNumberCell")
        return table
    }()
    
    private lazy var expandButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_sip_number_spread"), for: .normal)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(expandButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private var vendors: [VendorCalleeNumber] = []
    
    private var isExpanded = false
    private let kItemHeight: CGFloat = 44.0
    
    // MARK: - Initialization
    init(style: SIPPhoneListStyle = .global) {
        self.listStyle = style
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.listStyle = .global
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        addSubview(singleItemView)
        addSubview(tableView)
        addSubview(expandButton)
        
        singleItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(36)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(expandButton.snp.top)
            make.height.equalTo(28)
        }
        
        expandButton.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(28)
        }
    }
    
    func updateVendors(_ vendors: [VendorCalleeNumber]) {
        self.vendors = vendors
        tableView.reloadData()
        if vendors.count == 1, let firstVendor = vendors.first {
            singleItemView.configure(with: firstVendor)
        }
        updateViewExpand()
    }
    
    // MARK: - Actions
    @objc private func expandButtonTapped() {
        isExpanded = !isExpanded
        updateViewExpand()
    }
    
    @objc private func singleItemViewTapped() {
        guard !vendors.isEmpty else { return }
        let vendor = vendors[0]
        delegate?.sipPhoneListView(self, didSelectVendor: vendor, at: 0)
    }
    
    private func updateViewExpand() {
        let count = vendors.count
        let buttonHeight = 30
        let maxVisibleItems = 6
        
        expandButton.isHidden = true
        singleItemView.isHidden = true
        tableView.isHidden = true
        tableView.isScrollEnabled = false
        backgroundColor = .clear
        
        if count == 1 {
            singleItemView.isHidden = false
        } else if count < 4 {
            tableView.isHidden = false
            backgroundColor = UIColor.themColor(named: "ai_brand_white1")
            tableView.snp.updateConstraints { make in
                make.height.equalTo(kItemHeight * CGFloat(count))
            }
            expandButton.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
        } else {
            tableView.isHidden = false
            backgroundColor = UIColor.themColor(named: "ai_brand_white1")
            if isExpanded {
                let showCount = (count > maxVisibleItems) ? maxVisibleItems : count
                tableView.isScrollEnabled = (count > maxVisibleItems)
                tableView.snp.updateConstraints { make in
                    make.height.equalTo(kItemHeight * CGFloat(showCount))
                }
                expandButton.snp.updateConstraints { make in
                    make.height.equalTo(0)
                }
            } else {
                expandButton.isHidden = false
                tableView.snp.updateConstraints { make in
                    make.height.equalTo(kItemHeight * 3)
                }
                expandButton.snp.updateConstraints { make in
                    make.height.equalTo(buttonHeight)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension SIPPhoneListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vendors.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneNumberCell", for: indexPath) as! PhoneNumberCell
        let vendor = vendors[indexPath.row]
        
        // Configure cell with style
        cell.configure(with: listStyle)
        
        // Set data based on style
        switch listStyle {
        case .global:
            cell.flagEmojiLabel.text = vendor.flagEmoji ?? "🏳️"
            cell.countryCodeLabel.text = vendor.regionName ?? ""
            cell.phoneNumberLabel.text = vendor.phoneNumber ?? ""
        case .inland:
            cell.phoneNumberLabel.text = vendor.phoneNumber ?? ""
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SIPPhoneListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kItemHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vendor = vendors[indexPath.row]
        delegate?.sipPhoneListView(self, didSelectVendor: vendor, at: indexPath.row)
    }
}

// MARK: - Single Phone Number View
class SinglePhoneNumberView: UIView {
    
    // MARK: - Properties
    private let viewStyle: SIPPhoneListStyle
    private var dashedBorderLayer: CAShapeLayer?
    
    private lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 30)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        return label
    }()
    
    private lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 30)
        label.textAlignment = .left
        return label
    }()
    
    // MARK: - Initialization
    init(style: SIPPhoneListStyle = .global) {
        self.viewStyle = style
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.viewStyle = .global
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Setup dashed border
        setupDashedBorder()
        
        addSubview(phoneNumberLabel)
        
        // Add flag emoji label only for global style
        if viewStyle == .global {
            addSubview(flagEmojiLabel)
            flagEmojiLabel.snp.makeConstraints { make in
                make.left.top.bottom.equalToSuperview()
            }
            phoneNumberLabel.snp.makeConstraints { make in
                make.left.equalTo(flagEmojiLabel.snp.right).offset(8)
                make.right.top.bottom.equalToSuperview()
            }
        } else {
            // For inland style, phone number takes full width
            phoneNumberLabel.snp.makeConstraints { make in
                make.left.right.top.bottom.equalToSuperview()
            }
        }
    }
    
    private func setupDashedBorder() {
        // Remove existing layer if any
        dashedBorderLayer?.removeFromSuperlayer()
        
        // Create dashed border layer
        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = UIColor.themColor(named: "ai_icontext3").cgColor
        shapeLayer.lineWidth = 1
        shapeLayer.lineDashPattern = [2, 2]
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineJoin = .round
        
        layer.addSublayer(shapeLayer)
        dashedBorderLayer = shapeLayer
    }
    
    func configure(with vendor: VendorCalleeNumber) {
        // Handle flag emoji based on style
        if viewStyle == .global {
            flagEmojiLabel.text = vendor.flagEmoji ?? ""
        }
        setupGradientText(vendor.phoneNumber ?? "")
    }
    
    private func setupGradientText(_ text: String) {
        // Create gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "#2924FC")?.cgColor ?? UIColor.blue.cgColor,
            UIColor(hex: "#24F3FF")?.cgColor ?? UIColor.blue.cgColor,
            UIColor(hex: "#2924FC")?.cgColor ?? UIColor.blue.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.locations = [0, 0.5, 1.0]
        
        phoneNumberLabel.text = text
        phoneNumberLabel.layoutIfNeeded()
        
        let textSize = (text as NSString).size(withAttributes: [.font: phoneNumberLabel.font!])
        gradientLayer.frame = CGRect(x: 0, y: 0, width: textSize.width, height: textSize.height)
        
        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
            if let gradientImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                phoneNumberLabel.textColor = UIColor(patternImage: gradientImage)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDashedBorderPath()
        if let text = phoneNumberLabel.text {
            setupGradientText(text)
        }
    }
    
    private func updateDashedBorderPath() {
        guard let dashedBorderLayer = dashedBorderLayer else { return }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.height))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        
        dashedBorderLayer.path = path.cgPath
        dashedBorderLayer.frame = bounds
    }
}

// MARK: - Phone Number Cell
class PhoneNumberCell: UITableViewCell {
    
    // MARK: - Properties
    private var cellStyle: SIPPhoneListStyle?
    
    lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        return label
    }()
    
    lazy var countryCodeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .left
        return label
    }()
    
    lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .left
        return label
    }()
    
    lazy var phoneImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("ic_sip_list_phone")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSelectionStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    func configure(with style: SIPPhoneListStyle) {
        if cellStyle != style {
            self.cellStyle = style
            switch style {
            case .global:
                setupGlobalUI()
            case .inland:
                setupInlandUI()
            }
        }
    }
    
    private func setupGlobalUI() {
        backgroundColor = .clear
        
        // Add all subviews
        contentView.addSubview(flagEmojiLabel)
        contentView.addSubview(countryCodeLabel)
        contentView.addSubview(phoneImageView)
        contentView.addSubview(phoneNumberLabel)
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(24)
        }
        
        countryCodeLabel.snp.makeConstraints { make in
            make.left.equalTo(flagEmojiLabel.snp.right).offset(8)
            make.centerY.equalToSuperview()
        }
        
        phoneImageView.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        phoneNumberLabel.snp.makeConstraints { make in
            make.left.equalTo(countryCodeLabel.snp.right).offset(8)
            make.right.equalTo(phoneImageView.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
    }
    
    private func setupInlandUI() {
        backgroundColor = .clear
        
        // Add all subviews
        contentView.addSubview(phoneImageView)
        contentView.addSubview(phoneNumberLabel)
        
        // Create a container view for centering
        let containerView = UIView()
        containerView.backgroundColor = .clear
        contentView.addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        containerView.addSubview(phoneNumberLabel)
        containerView.addSubview(phoneImageView)
        phoneNumberLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        phoneImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.left.equalTo(phoneNumberLabel.snp.right).offset(4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }
    
    // MARK: - Selection Style Setup
    
    private lazy var highlightView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_click_app")
        view.layer.cornerRadius = 8
        view.isHidden = true
        return view
    }()
    
    private func setupSelectionStyle() {
        // Add highlight view to contentView
        contentView.insertSubview(highlightView, at: 0)
        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }
        
        // Set selection style to none since we're using custom highlight
        selectionStyle = .none
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Show/hide highlight view with animation
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.highlightView.isHidden = !selected
                self.highlightView.alpha = selected ? 1.0 : 0.0
            }
        } else {
            highlightView.isHidden = !selected
            highlightView.alpha = selected ? 1.0 : 0.0
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        // Show/hide highlight view with animation
        if animated {
            UIView.animate(withDuration: 0.1) {
                self.highlightView.isHidden = !highlighted
                self.highlightView.alpha = highlighted ? 1.0 : 0.0
            }
        } else {
            highlightView.isHidden = !highlighted
            highlightView.alpha = highlighted ? 1.0 : 0.0
        }
    }
}
