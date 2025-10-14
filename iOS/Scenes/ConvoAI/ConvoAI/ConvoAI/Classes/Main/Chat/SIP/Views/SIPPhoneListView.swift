//
//  SIPPhoneListView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import Common

// MARK: - Phone Number Model
struct PhoneNumber {
    let regionName: String
    let flagEmoji: String?
    let phoneNumber: String
    
    var displayNumber: String {
        return phoneNumber
    }
}

// MARK: - Delegate Protocol
protocol SIPPhoneListViewDelegate: AnyObject {
    func sipPhoneListView(_ listView: SIPPhoneListView, didSelectPhoneNumber phoneNumber: PhoneNumber, at index: Int)
}

class SIPPhoneListView: UIView {
    
    // MARK: - Delegate
    weak var delegate: SIPPhoneListViewDelegate?
    
    private lazy var singleItemView: SinglePhoneNumberView = {
        let view = SinglePhoneNumberView()
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
    
    private var phoneNumbers: [PhoneNumber] = []

    private var isExpanded = false
    private let kItemHeight: CGFloat = 44.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
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
    
    func updatePhoneNumbers(_ numbers: [PhoneNumber]) {
        phoneNumbers = numbers
        tableView.reloadData()
        if numbers.count == 1, let firstNumber = numbers.first {
            singleItemView.configure(with: firstNumber)
        }
        updateViewExpand()
    }
    
    // MARK: - Actions
    @objc private func expandButtonTapped() {
        isExpanded = !isExpanded
        updateViewExpand()
    }

    @objc private func singleItemViewTapped() {
        guard !phoneNumbers.isEmpty else { return }
        let phoneNumber = phoneNumbers[0]
        delegate?.sipPhoneListView(self, didSelectPhoneNumber: phoneNumber, at: 0)
    }
    
    private func updateViewExpand() {
        let count = phoneNumbers.count
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
        return phoneNumbers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneNumberCell", for: indexPath) as! PhoneNumberCell
        let phoneNumber = phoneNumbers[indexPath.row]
        cell.flagEmojiLabel.text = phoneNumber.flagEmoji ?? "🏳️"
        cell.countryCodeLabel.text = phoneNumber.regionName
        cell.phoneNumberLabel.text = phoneNumber.displayNumber
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
        let phoneNumber = phoneNumbers[indexPath.row]
        delegate?.sipPhoneListView(self, didSelectPhoneNumber: phoneNumber, at: indexPath.row)
    }
}

// MARK: - Single Phone Number View
class SinglePhoneNumberView: UIView {
    
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
        
        // Setup dashed border
        setupDashedBorder()
        
        addSubview(flagEmojiLabel)
        addSubview(phoneNumberLabel)
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
        }
        
        phoneNumberLabel.snp.makeConstraints { make in
            make.left.equalTo(flagEmojiLabel.snp.right).offset(8)
            make.right.top.bottom.equalToSuperview()
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
    
    func configure(with phoneNumber: PhoneNumber) {
        flagEmojiLabel.text = phoneNumber.flagEmoji ?? ""
        setupGradientText(phoneNumber.displayNumber)
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
    
    lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        label.isHidden = false
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
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(flagEmojiLabel)
        contentView.addSubview(phoneImageView)
        contentView.addSubview(phoneNumberLabel)
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(24)
        }
        
        phoneImageView.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        phoneNumberLabel.snp.makeConstraints { make in
            make.left.equalTo(flagEmojiLabel.snp.right).offset(8)
            make.right.equalTo(phoneImageView.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
    }
}
