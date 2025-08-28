//
//  AgentSettingSubOptionCell.swift
//  Agent
//
//  Created by Jonathan on 2024/10/1.
//

import UIKit
import Common

class AgentSettingSubOptionCell: UITableViewCell {
    private lazy var checkImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage.ag_named("ic_agent_setting_sel"))
        imageView.isHidden = true
        return imageView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = .systemFont(ofSize: 15)
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = .systemFont(ofSize: 12)
        label.numberOfLines = 0
        return label
    }()
    
    let bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_line1")
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_block3")
        selectionStyle = .none
        [titleLabel, subtitleLabel, bottomLine, checkImageView].forEach { contentView.addSubview($0) }
                
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.top.equalTo(8)
            make.right.lessThanOrEqualTo(checkImageView.snp.left).offset(-12)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.right.equalTo(titleLabel)
            make.bottom.equalTo(-8)
        }
        
        checkImageView.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        bottomLine.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func configure(with title: String, subtitle: String, isSelected: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle.isEmpty
        checkImageView.isHidden = !isSelected
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
