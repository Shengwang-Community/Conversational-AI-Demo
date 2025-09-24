//
//  SIPPhoneAreaListView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/22.
//

import UIKit
import SnapKit
import Common

protocol SIPPhoneAreaListViewDelegate: AnyObject {
    func phoneAreaListView(_ listView: SIPPhoneAreaListView, didSelectCountry region: RegionConfig)
}

class SIPPhoneAreaListView: UIView {
    
    weak var delegate: SIPPhoneAreaListViewDelegate?
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.themColor(named: "ai_fill4")
        tableView.layer.cornerRadius = 12
        tableView.layer.masksToBounds = true
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = true
        tableView.register(CountryCell.self, forCellReuseIdentifier: "CountryCell")
        return tableView
    }()
    
    // MARK: - Properties
    private var regions: [RegionConfig] = []
    private var isVisible = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupCountries()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupCountries()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        isHidden = true
        alpha = 0.0
        
        addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupCountries() {
        let regionCodes = ["IN", "CL"]
        
        regions = RegionConfigManager.shared.allRegions
    }
    
    // MARK: - Public Methods
    func show() {
        guard !isVisible else { return }
        isVisible = true
        
        UIView.animate(withDuration: 0.3) {
            self.isHidden = false
            self.alpha = 1.0
        }
    }
    
    func hide() {
        guard isVisible else { return }
        isVisible = false
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0.0
        } completion: { _ in
            self.isHidden = true
        }
    }
}

// MARK: - UITableViewDataSource
extension SIPPhoneAreaListView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return regions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CountryCell", for: indexPath) as! CountryCell
        cell.configure(with: regions[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SIPPhoneAreaListView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedCountry = regions[indexPath.row]
        delegate?.phoneAreaListView(self, didSelectCountry: selectedCountry)
        hide()
    }
}

// MARK: - Country Cell
class CountryCell: UITableViewCell {
    
    private lazy var flagEmojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        return label
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    private lazy var dialCodeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .right
        return label
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
        contentView.addSubview(nameLabel)
        contentView.addSubview(dialCodeLabel)
        
        flagEmojiLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(flagEmojiLabel.snp.right).offset(12)
            make.centerY.equalToSuperview()
            make.right.equalTo(dialCodeLabel.snp.left).offset(-8)
        }
        
        dialCodeLabel.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }
    }
    
    func configure(with region: RegionConfig) {
        flagEmojiLabel.text = region.flagEmoji
        nameLabel.text = region.regionCode
        dialCodeLabel.text = region.dialCode
    }
}
