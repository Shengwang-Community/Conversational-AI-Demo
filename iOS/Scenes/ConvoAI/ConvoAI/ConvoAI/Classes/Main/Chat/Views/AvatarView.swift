//
//  AvatarView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/7/9.
//

import Foundation
import Common

class AvatarView: UIView {
    var useSpatiusStage = false {
        didSet {
            guard useSpatiusStage != oldValue else { return }
            backgroundImageView.snp.removeConstraints()
            renderView.snp.removeConstraints()
            if useSpatiusStage {
                // SnapKit disabled autoresizing-mask translation. Restore it when
                // switching to frames so AvatarKit's constrained children inherit
                // the stage size instead of resolving to a zero-sized Metal view.
                backgroundImageView.translatesAutoresizingMaskIntoConstraints = true
                renderView.translatesAutoresizingMaskIntoConstraints = true
                backgroundColor = UIColor.themColor(named: "ai_fill2").withAlphaComponent(1)
                bringSubviewToFront(backgroundImageView)
            } else {
                backgroundColor = .clear
                bringSubviewToFront(renderView)
                setupConstraints()
            }
            setSpatiusRenderReady(false)
            clipsToBounds = useSpatiusStage
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard useSpatiusStage else { return }
        backgroundImageView.frame = bounds
        renderView.frame = SpatiusStageLayout.frame(in: bounds)
    }

    func setSpatiusRenderReady(_ ready: Bool) {
        // Backend posters contain a person; never keep them behind a transparent live avatar.
        backgroundImageView.isHidden = useSpatiusStage && ready
    }

    lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    lazy var renderView: UIView = {
        let view = UIView()
        
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        addSubview(backgroundImageView)
        addSubview(renderView)
    }
    
    func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        renderView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
    }
}
