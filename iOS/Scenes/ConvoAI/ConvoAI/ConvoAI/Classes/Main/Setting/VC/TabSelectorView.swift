//
//  TabSelectorView.swift
//  ConvoAI
//
//  Created by qinhui on 2024/12/19.
//

import UIKit
import Common

protocol TabSelectorViewDelegate: AnyObject {
    func tabSelectorView(_ selectorView: TabSelectorView, didSelectTabAt index: Int)
}

class TabSelectorView: UIView {
    
    weak var delegate: TabSelectorViewDelegate?
    private var currentSelectedIndex: Int = 0
    private var tabButtons: [UIButton] = []
    
    struct TabItem {
        let title: String
        let iconName: String
    }
    
    private var tabItems: [TabItem] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.themColor(named: "ai_fill1")
    }
    
    func configure(with items: [TabItem], selectedIndex: Int = 0) {
        self.tabItems = items
        self.currentSelectedIndex = selectedIndex
        
        // Remove existing buttons
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()
        
        // Create new buttons
        for (index, item) in items.enumerated() {
            let button = createTabButton(with: item, tag: index)
            addSubview(button)
            tabButtons.append(button)
        }
        
        setupConstraints()
        updateButtonAppearance()
    }
    
    private func createTabButton(with item: TabItem, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(item.title, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext3"), for: .normal)
        button.setTitleColor(UIColor.white, for: .selected)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.clear
        button.layer.cornerRadius = 12
        button.tag = tag
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.addTarget(self, action: #selector(onTabButtonTapped(_:)), for: .touchUpInside)
        
        button.setImage(UIImage.ag_named(item.iconName), for: .normal)
        button.tintColor = UIColor.themColor(named: "ai_icontext3")
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        
        return button
    }
    
    private func setupConstraints() {
        guard !tabButtons.isEmpty else { return }
        
        let spacing: CGFloat = 12
        let sideMargin: CGFloat = 2
        
        for (index, button) in tabButtons.enumerated() {
            button.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.height.equalTo(38)
                
                if index == 0 {
                    make.left.equalTo(sideMargin)
                } else {
                    make.left.equalTo(tabButtons[index - 1].snp.right).offset(spacing)
                }
                
                if index == tabButtons.count - 1 {
                    make.right.lessThanOrEqualTo(-sideMargin)
                }
                
                // Make all buttons equal width
                if tabButtons.count > 1 {
                    if index > 0 {
                        make.width.equalTo(tabButtons[0])
                    }
                }
            }
        }
        
        // For equal distribution, calculate available width
        if tabButtons.count > 1 {
            let totalSpacing = CGFloat(tabButtons.count - 1) * spacing + sideMargin * 2
            tabButtons[0].snp.makeConstraints { make in
                make.width.equalTo(self).dividedBy(tabButtons.count).offset(-totalSpacing / CGFloat(tabButtons.count))
            }
        } else if tabButtons.count == 1 {
            tabButtons[0].snp.makeConstraints { make in
                make.right.equalTo(-sideMargin)
            }
        }
    }
    
    @objc private func onTabButtonTapped(_ sender: UIButton) {
        let newIndex = sender.tag
        if newIndex == currentSelectedIndex { return }
        
        currentSelectedIndex = newIndex
        updateButtonAppearance()
        delegate?.tabSelectorView(self, didSelectTabAt: newIndex)
    }
    
    private func updateButtonAppearance() {
        for (index, button) in tabButtons.enumerated() {
            if index == currentSelectedIndex {
                button.isSelected = true
                button.backgroundColor = UIColor.themColor(named: "ai_brand_main6")
                button.setTitleColor(UIColor.white, for: .normal)
                button.tintColor = UIColor.white
            } else {
                button.isSelected = false
                button.backgroundColor = UIColor.clear
                button.setTitleColor(UIColor.themColor(named: "ai_icontext3"), for: .normal)
                button.tintColor = UIColor.themColor(named: "ai_icontext3")
            }
        }
    }
    
    func setSelectedIndex(_ index: Int) {
        guard index >= 0 && index < tabButtons.count else { return }
        currentSelectedIndex = index
        updateButtonAppearance()
    }
} 
