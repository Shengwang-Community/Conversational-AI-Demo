//
//  SideNavigationBar.swift
//  ConvoAI
//
//  Created by qinhui on 2025/8/5.
//

import Foundation
import Common

class SideNavigationBar: UIView {
    var showTipsTimer: Timer?
    let centerTitleButton = UIButton()
    
    private let titleContentView = {
       let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var centerTipsLabel: UILabel = {
        let label = UILabel()
        label.text = String(format: ResourceManager.L10n.Join.tips, 10)
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private let countDownLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.isHidden = true
        label.textColor = UIColor.themColor(named: "ai_brand_white10")
        return label
    }()
    
    private let centerTitleView = UIView()
    private var isShowTips: Bool = false
    private var isAnimationInprogerss = false
    private var isLimited = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("SideNavigationBar fatalError")
    }
    
    func setupViews() {
        [titleContentView, countDownLabel].forEach { addSubview($0) }
        [centerTipsLabel, centerTitleView, centerTitleButton].forEach { titleContentView.addSubview($0) }
        let titleImageView = UIImageView()
        titleImageView.image = UIImage.ag_named("ic_agent_detail_logo")
        centerTitleView.addSubview(titleImageView)
        titleImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = ResourceManager.L10n.Join.title
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        centerTitleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(titleImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
    }
    
    func setupConstraints() {
        titleContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        centerTitleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        centerTipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalTo(self.snp.bottom)
        }
        
        centerTitleButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        countDownLabel.snp.makeConstraints { make in
            make.width.equalTo(49)
            make.height.equalTo(22)
            make.center.equalToSuperview()
        }
    }
    
    private func hideTips() {
        isShowTips = false
        if (isAnimationInprogerss) {
            return
        }
        isAnimationInprogerss = true
        self.layer.removeAllAnimations()
        
        self.centerTitleView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        self.centerTipsLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.top.equalTo(self.snp.bottom)
        }
        
        self.isAnimationInprogerss = false
        if self.isShowTips == true {
            self.showTips()
        }
    }
    
    private func showTips() {
        isShowTips = true
        if (isAnimationInprogerss) {
            return
        }
        isAnimationInprogerss = true
        self.centerTitleView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalTo(self.snp.top)
        }
        self.centerTipsLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        UIView.animate(withDuration: 1.0) {
            self.layoutIfNeeded()
        } completion: { isFinish in
            self.centerTitleView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.height.equalToSuperview()
                make.top.equalTo(self.snp.bottom)
            }
            self.layoutIfNeeded()
            self.isAnimationInprogerss = false
            if self.isShowTips == false {
                self.hideTips()
            }
        }
    }
    
    func showTips(seconds: Int = 10 * 60) {
        showTipsTimer?.invalidate()
        showTipsTimer = nil
        self.isHidden = false
        
        if seconds == 0 {
            isLimited = false
            centerTipsLabel.text = ResourceManager.L10n.Join.tipsNoLimit
        } else {
            isLimited = true
            let minutes = seconds / 60
            centerTipsLabel.text = String(format: ResourceManager.L10n.Join.tips, minutes)
        }
        showTips()
        showTipsTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(3), repeats: false) { [weak self] _ in
            if self?.isShowTips == true {
                self?.hideTips()
            }
            self?.showTipsTimer?.invalidate()
            self?.showTipsTimer = nil
            self?.countDownLabel.isHidden = false
            self?.centerTitleView.isHidden = true
        }
    }
    
    func updateRestTime(_ seconds: Int) {
        if isLimited {
            if seconds < 20 {
                countDownLabel.textColor = UIColor.themColor(named: "ai_red6")
            } else if seconds < 59 {
                countDownLabel.textColor = UIColor.themColor(named: "ai_green6")
            } else {
                countDownLabel.textColor = UIColor.themColor(named: "ai_brand_white10")
            }
        } else {
            countDownLabel.textColor = UIColor.themColor(named: "ai_brand_white10")
        }
        let minutes = seconds / 60
        let s = seconds % 60
        countDownLabel.text = String(format: "%02d:%02d", minutes, s)
    }
    
    func stop() {
        countDownLabel.isHidden = true
        centerTitleView.isHidden = false
        
        showTipsTimer?.invalidate()
        showTipsTimer = nil
        if isShowTips == true {
            hideTips()
        }
        
        self.isHidden = true
    }
}
