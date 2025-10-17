//
//  CharactersInformationView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/6.
//

import Foundation
import Common
import Kingfisher

class CharactersInformationView: UIView {
    private lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()
    
    
    public lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .clear
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.themColor(named: "ai_brand_white6").cgColor
        
        return imageView
    }()
    
    public lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        label.font = .systemFont(ofSize: 10, weight: .medium)
        return label
    }()
    
    public lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(subtitleLabel)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(32)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.left.equalTo(6)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 20, height: 20))
        }
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.right.equalTo(-6)
            make.centerY.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.center.equalTo(nameLabel)
        }
    }
    
    func configure(icon: String, defaultIcon: String, name: String, subtitle: String) {
        avatarImageView.kf.setImage(with: URL(string: icon), placeholder: UIImage.ag_named(defaultIcon))
        nameLabel.text = name
        subtitleLabel.text = subtitle
    }
    
    // MARK: - Public Methods
    
    func showNameLabel(animated: Bool = true) {
        guard animated else {
            nameLabel.isHidden = false
            subtitleLabel.isHidden = true
            setupNameLabelConstraints()
            return
        }
        
        guard !subtitleLabel.isHidden else { return }
        
        nameLabel.isHidden = false
        nameLabel.transform = CGAffineTransform(translationX: 0, y: -20)
        nameLabel.alpha = 0
        
        // Set constraints for nameLabel
        setupNameLabelConstraints()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            self.subtitleLabel.alpha = 0
            
            self.nameLabel.transform = .identity
            self.nameLabel.alpha = 1
        }) { _ in
            self.subtitleLabel.isHidden = true
            self.subtitleLabel.transform = .identity
            self.subtitleLabel.alpha = 1
        }
    }
    
    func showSubtitleLabel(animated: Bool = true) {
        guard animated else {
            nameLabel.isHidden = true
            subtitleLabel.isHidden = false
            setupSubtitleLabelConstraints()
            return
        }
        
        guard !nameLabel.isHidden else { return }
        
        subtitleLabel.isHidden = false
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        subtitleLabel.alpha = 0
        
        // Set constraints for subtitleLabel
        setupSubtitleLabelConstraints()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.nameLabel.transform = CGAffineTransform(translationX: 0, y: -20)
            self.nameLabel.alpha = 0
            
            self.subtitleLabel.transform = .identity
            self.subtitleLabel.alpha = 1
        }) { _ in
            self.nameLabel.isHidden = true
            self.nameLabel.transform = .identity
            self.nameLabel.alpha = 1
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNameLabelConstraints() {
        subtitleLabel.snp.remakeConstraints { make in
            make.center.equalTo(nameLabel)
        }
        nameLabel.snp.remakeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.right.equalTo(-6)
            make.centerY.equalToSuperview()
        }
    }
    
    private func setupSubtitleLabelConstraints() {
        subtitleLabel.snp.remakeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.right.equalTo(-6)
            make.centerY.equalToSuperview()
        }
        nameLabel.snp.remakeConstraints { make in
            make.center.equalTo(subtitleLabel)
        }
    }
}
