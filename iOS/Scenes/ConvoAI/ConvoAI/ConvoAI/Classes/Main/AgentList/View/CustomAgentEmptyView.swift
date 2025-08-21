//
//  EmptyStateView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/26.
//

import UIKit
import SnapKit
import Common

class CustomAgentEmptyView: UIView {

    private var dashedLayer: CAShapeLayer?

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage.ag_named("img_empty_list")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.AgentList.getAgent
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = ResourceManager.L10n.AgentList.contact
        label.textColor = UIColor.themColor(named: "ai_icontext3")
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDashedBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalTo(16)
            make.right.equalTo(-16)
        }
    }

    private func updateDashedBorder() {
        dashedLayer?.removeFromSuperlayer()

        let dashedLayer = CAShapeLayer()
        dashedLayer.strokeColor = UIColor.themColor(named: "ai_line1").cgColor
        dashedLayer.lineDashPattern = [4, 4]
        dashedLayer.frame = bounds
        dashedLayer.fillColor = nil
        dashedLayer.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: 24).cgPath
        dashedLayer.lineWidth = 2
        layer.insertSublayer(dashedLayer, at: 0)
        self.dashedLayer = dashedLayer
    }
}
