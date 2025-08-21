//
//  CovSegmentedControl.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/25.
//

import UIKit
import SnapKit
import Common

protocol CovSegmentedControlDelegate: AnyObject {
    func didChange(to index: Int)
}

class CovSegmentedControl: UIView {

    private var buttonTitles: [String]!
    private var buttons: [UIButton] = []
    private var selectorView: UIView!
    private var stackView: UIStackView!

    weak var delegate: CovSegmentedControlDelegate?

    var textColor = UIColor.themColor(named: "ai_toast")
    var selectorTextColor = UIColor.themColor(named: "ai_icontext_inverse1")

    var selectedIndex: Int = 0 {
        didSet {
            if oldValue != selectedIndex {
                updateViewForSelectedIndex()
            }
        }
    }

    convenience init(frame: CGRect, buttonTitles: [String]) {
        self.init(frame: frame)
        self.buttonTitles = buttonTitles
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height * 0.5
        selectorView?.layer.cornerRadius = bounds.height * 0.5
    }

    func setButtonTitles(buttonTitles: [String]) {
        self.buttonTitles = buttonTitles
        updateButtons()
    }

    private func setupUI() {
        self.backgroundColor = UIColor.themColor(named: "ai_fill2")
        selectorView = UIView()
        selectorView.backgroundColor = UIColor.themColor(named: "ai_toast")
        addSubview(selectorView)
        configStackView()
        updateButtons()
        
        selectorView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(1.0 / CGFloat(buttons.count))
            make.leading.equalToSuperview()
        }
    }

    private func updateButtons() {
        createButtons()
        updateViewForSelectedIndex()
    }

    private func configStackView() {
        stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        for buttonTitle in buttonTitles {
            let button = UIButton(type: .system)
            button.setTitle(buttonTitle, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            button.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }

    @objc func buttonAction(sender: UIButton) {
        guard let index = buttons.firstIndex(of: sender) else { return }
        if selectedIndex != index {
            selectedIndex = index
            delegate?.didChange(to: index)
        }
    }

    private func updateViewForSelectedIndex() {
        updateSelectorPosition()
        updateButtonColors()
    }

    private func updateSelectorPosition() {
        guard !buttons.isEmpty else { return }
        let selectedButton = buttons[selectedIndex]

        selectorView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalTo(selectedButton.snp.width)
            make.centerX.equalTo(selectedButton.snp.centerX)
        }

        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }

    private func updateButtonColors() {
        for (buttonIndex, btn) in buttons.enumerated() {
            let isSelected = (buttonIndex == selectedIndex)
            btn.setTitleColor(isSelected ? selectorTextColor : textColor, for: .normal)
        }
    }
    
    public func moveSelector(with progress: CGFloat) {
        let fromIndex = selectedIndex
        var toIndex = selectedIndex

        if progress > 0 {
            toIndex = fromIndex + 1
        } else {
            toIndex = fromIndex - 1
        }

        guard fromIndex >= 0, fromIndex < buttons.count,
              toIndex >= 0, toIndex < buttons.count else {
            return
        }

        let fromButton = buttons[fromIndex]
        let toButton = buttons[toIndex]

        // --- CenterX Calculation ---
        let distance = toButton.center.x - fromButton.center.x
        let newCenterX = fromButton.center.x + distance * abs(progress)

        // --- Width Calculation ---
        let p = abs(progress)
        let fullWidth = fromButton.bounds.width
        
        guard fullWidth > 0 else { return }

        // The slider shrinks to 80% of its size at the midpoint of the transition.
        let minWidthFactor: CGFloat = 0.62
        let minWidth = fullWidth * minWidthFactor
        
        // This is a parabolic function for width change:
        // It's `fullWidth` at p=0 and p=1, and `minWidth` at p=0.5.
        let widthChange = 4 * (fullWidth - minWidth) * p * (p - 1)
        let newWidth = fullWidth + widthChange

        selectorView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalTo(newWidth)
            make.centerX.equalTo(self.snp.leading).offset(newCenterX)
        }
        
        // Update button colors based on progress
        updateButtonColorsWithProgress(progress: p, fromIndex: fromIndex, toIndex: toIndex)
    }
    
    private func updateButtonColorsWithProgress(progress: CGFloat, fromIndex: Int, toIndex: Int) {
        for (buttonIndex, button) in buttons.enumerated() {
            if buttonIndex == fromIndex {
                // From button: fade from selected to unselected
                let color = interpolateColor(from: selectorTextColor, to: textColor, with: progress)
                button.setTitleColor(color, for: .normal)
            } else if buttonIndex == toIndex {
                // To button: fade from unselected to selected
                let color = interpolateColor(from: textColor, to: selectorTextColor, with: progress)
                button.setTitleColor(color, for: .normal)
            } else {
                // Other buttons: keep unselected color
                button.setTitleColor(textColor, for: .normal)
            }
        }
    }
    
    private func interpolateColor(from: UIColor, to: UIColor, with percent: CGFloat) -> UIColor {
        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0
        
        from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        
        let r = fromR + (toR - fromR) * percent
        let g = fromG + (toG - fromG) * percent
        let b = fromB + (toB - fromB) * percent
        let a = fromA + (toA - fromA) * percent
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
