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
    let countryCode: String
    let flagEmoji: String?  // Flag emoji field
    let phoneNumber: String     // For dialing (clean format)
    
    // Computed property for display format
    var displayNumber: String {
        return phoneNumber  // Can be customized for formatting if needed
    }
}

class SIPPhoneListView: UIView {
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = UIColor.clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.register(PhoneNumberCell.self, forCellReuseIdentifier: "PhoneNumberCell")
        return table
    }()
    
    // MARK: - Properties
    private var phoneNumbers: [PhoneNumber] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupData()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.snp.makeConstraints { make in
            make.height.equalTo(90)
        }
    }
    
    private func setupData() {
        let phoneConfigs = [
            ("IN", "22-47790159"),
            ("CL", "911-52465127")
        ]
        
        phoneNumbers = phoneConfigs.compactMap { (countryCode, phoneNumber) in
            guard let countryConfig = CountryConfigManager.shared.getCountryByCode(countryCode) else {
                return nil
            }
            
            let fullPhoneNumber = "\(countryConfig.dialCode)-\(phoneNumber)"
            
            return PhoneNumber(
                countryCode: countryConfig.countryCode,
                flagEmoji: countryConfig.flagEmoji,
                phoneNumber: fullPhoneNumber
            )
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Public Methods
    func updatePhoneNumbers(_ numbers: [PhoneNumber]) {
        phoneNumbers = numbers
        tableView.reloadData()
    }
    
    // MARK: - Private Methods
    private func makePhoneCall(phoneNumber: String) {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "-", with: "")
        
        if let phoneURL = URL(string: "tel://\(cleanedNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    private func showCallAlert(phoneNumber: String) {
        guard let topViewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(title: "Make a phone call", message: "Do you want to make a call? \(phoneNumber)?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Dial", style: .default) { _ in
            // On actual devices, it will directly dial the phone
            print("Dialing phone: \(phoneNumber)")
        })
        
        topViewController.present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SIPPhoneListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return phoneNumbers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneNumberCell", for: indexPath) as! PhoneNumberCell
        cell.configure(with: phoneNumbers[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SIPPhoneListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let phoneNumber = phoneNumbers[indexPath.row]
        makePhoneCall(phoneNumber: phoneNumber.phoneNumber)
    }
}

// MARK: - Phone Number Cell
class PhoneNumberCell: UITableViewCell {
    
    private lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 35)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        label.isHidden = false
        return label
    }()
    
    private lazy var countryCodeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .left
        return label
    }()
    
    private lazy var phoneNumberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.textAlignment = .left
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [flagEmojiLabel, countryCodeLabel, phoneNumberLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        return stack
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
        
        contentView.addSubview(stackView)
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
            make.height.equalTo(44)
        }
        
        countryCodeLabel.snp.makeConstraints { make in
            make.width.equalTo(30)
        }
        
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.centerY.equalToSuperview()
        }
    }
    
    func configure(with phoneNumber: PhoneNumber) {
        // Set flag emoji
        flagEmojiLabel.text = phoneNumber.flagEmoji ?? "🏳️"
        
        // Set country code
        countryCodeLabel.text = phoneNumber.countryCode
        
        // Set phone number with underline
        let attributedString = NSMutableAttributedString(string: phoneNumber.displayNumber)
        attributedString.addAttribute(.underlineStyle, 
                                    value: NSUnderlineStyle.single.rawValue, 
                                    range: NSRange(location: 0, length: phoneNumber.displayNumber.count))
        attributedString.addAttribute(.underlineColor, 
                                    value: UIColor.white, 
                                    range: NSRange(location: 0, length: phoneNumber.displayNumber.count))
        
        phoneNumberLabel.attributedText = attributedString
    }
}
