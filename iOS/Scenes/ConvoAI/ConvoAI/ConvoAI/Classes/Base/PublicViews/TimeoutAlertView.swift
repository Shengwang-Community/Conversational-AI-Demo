//
//  TimeoutAlertView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/20.
//

import UIKit
import Common

class TimeoutAlertView: UIView {
    var onConfirmButtonTapped: (() -> Void)?
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.themColor(named: "ai_fill2")
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var cardView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFang HK", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(ResourceManager.L10n.ChannelInfo.timeLimitdAlertConfim, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.27, green: 0.42, blue: 1, alpha: 1)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()
    
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
        
        containerView.addSubview(cardView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        containerView.addSubview(confirmButton)
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalTo(30)
            make.right.equalTo(-30)
        }
        
        cardView.snp.makeConstraints { make in
            make.top.equalTo(containerView)
            make.left.equalTo(containerView)
            make.right.equalTo(containerView)
            make.height.equalTo(cardView.snp.width).multipliedBy(180.0/315.0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(cardView.snp.bottom).offset(20)
            make.left.equalTo(containerView).offset(20)
            make.right.equalTo(containerView).offset(-20)
        }
        
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.equalTo(containerView).offset(24)
            make.right.equalTo(containerView).offset(-24)
        }
        
        confirmButton.snp.makeConstraints { make in
            make.left.equalTo(containerView).offset(24)
            make.right.equalTo(containerView).offset(-24)
            make.top.equalTo(contentLabel.snp.bottom).offset(20)
            make.bottom.equalTo(containerView).offset(-24)
            make.height.equalTo(40)
        }
    }
    
    static func show(
        in view: UIView,
        image: UIImage?,
        title: String,
        description: String,
        onConfirm: (() -> Void)? = nil
    ) {
        let alertView = TimeoutAlertView(frame: view.bounds)
        alertView.cardView.image = image ?? UIImage.ag_named("ic_alert_timeout_icon")
        alertView.titleLabel.text = title
        alertView.contentLabel.text = description
        alertView.onConfirmButtonTapped = onConfirm
        alertView.show(in: view)
    }
    
    private func show(in view: UIView) {
        view.addSubview(self)
        
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        backgroundView.alpha = 0
        
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
            self.backgroundView.alpha = 1
        }
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.containerView.alpha = 0
            self.backgroundView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    @objc private func confirmButtonTapped() {
        dismiss { [weak self] in
            self?.onConfirmButtonTapped?()
        }
    }
}
