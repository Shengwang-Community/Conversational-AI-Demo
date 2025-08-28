//
//  SwitchableIconButton.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/6.
//

import UIKit

class SwitchableIconButton: UIView {
    enum IconState {
        case photo
        case camera
    }
    
    public var onTap: ((IconState) -> Void)?
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.isScrollEnabled = false
        return scrollView
    }()
    
    private lazy var button: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var topIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var bottomIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
        
    public var currentState: IconState {
        let isAtBottom = scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height
        return isAtBottom ? .camera : .photo
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(scrollView)
        addSubview(button)
        [topIconView, bottomIconView].forEach { scrollView.addSubview($0) }
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        topIconView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        bottomIconView.snp.makeConstraints { make in
            make.top.equalTo(topIconView.snp.bottom)
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalTo(0)
        }
    }
    
    func configure(topIcon: UIImage?, bottomIcon: UIImage?) {
        topIconView.image = topIcon
        bottomIconView.image = bottomIcon
        scrollView.contentOffset = .zero
    }
    
    func switchIcon(animated: Bool = true) {
        let duration: TimeInterval = animated ? 0.3 : 0
        let isAtBottom = scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.bounds.height
        
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            if isAtBottom {
                self.scrollView.setContentOffset(.zero, animated: false)
            } else {
                self.scrollView.setContentOffset(CGPoint(x: 0, y: self.scrollView.bounds.height), animated: false)
            }
        }
    }
    
    @objc private func buttonTapped() {
        onTap?(currentState)
    }
}
