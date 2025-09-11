//
//  DigitalHumanSegmentView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/11.
//

import UIKit
import Common
import SnapKit

protocol DigitalHumanSegmentViewDelegate: AnyObject {
    func digitalHumanSegmentView(_ view: DigitalHumanSegmentView, didSelectSegmentAt index: Int)
}

class DigitalHumanSegmentView: UIView {
    
    // MARK: - Properties
    weak var delegate: DigitalHumanSegmentViewDelegate?
    
    private var selectedIndex: Int = 0 {
        didSet {
            updateSelectedSegment()
        }
    }
    
    private var segments: [String] = [] {
        didSet {
            setupSegments()
        }
    }
    
    // MARK: - UI Components
    private lazy var segmentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 1
        return view
    }()
    
    private var segmentButtons: [UIButton] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupSegments()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupSegments()
        setupConstraints()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(segmentStackView)
        addSubview(indicatorView)
    }
    
    private func setupConstraints() {
        segmentStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.lessThanOrEqualToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
        }
        
        indicatorView.snp.makeConstraints { make in
            make.width.equalTo(20)
            make.height.equalTo(2)
            make.bottom.equalToSuperview()
        }
    }
    
    private func setupSegments() {
        // Clear existing segments
        segmentButtons.forEach { $0.removeFromSuperview() }
        segmentButtons.removeAll()
        
        // Create new segments
        for (index, segment) in segments.enumerated() {
            let button = createSegmentButton(text: segment, isSelected: index == selectedIndex, tag: index)
            segmentButtons.append(button)
            segmentStackView.addArrangedSubview(button)
        }
        
        updateSelectedSegment()
    }
    
    private func createSegmentButton(text: String, isSelected: Bool, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = isSelected ? UIFont.systemFont(ofSize: 16, weight: .semibold) : UIFont.systemFont(ofSize: 13, weight: .regular)
        button.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.75), for: .normal)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.baselineAdjustment = .alignBaselines
        button.tag = tag
        button.addTarget(self, action: #selector(segmentButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    @objc private func segmentButtonTapped(_ button: UIButton) {
        let index = button.tag
        selectSegment(at: index)
        delegate?.digitalHumanSegmentView(self, didSelectSegmentAt: index)
    }
    
    // MARK: - Public Methods
    func setSegments(_ segments: [String]) {
        self.segments = segments
        selectedIndex = 0 // Reset to first segment
    }
    
    func selectSegment(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        selectedIndex = index
    }
    
    func getSelectedSegment() -> String {
        return segments[selectedIndex]
    }
    
    // MARK: - Private Methods
    private func updateSelectedSegment() {
        for (index, button) in segmentButtons.enumerated() {
            let isSelected = index == selectedIndex
            
            UIView.performWithoutAnimation {
                button.titleLabel?.font = isSelected ? UIFont.systemFont(ofSize: 16, weight: .semibold) : UIFont.systemFont(ofSize: 13, weight: .regular)
                button.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.75), for: .normal)
                button.titleLabel?.baselineAdjustment = .alignBaselines
            }
        }
        
        layoutIfNeeded()
        
        // Update indicator position and width
        updateIndicatorPosition()
    }
    
    private func updateIndicatorPosition() {
        guard selectedIndex < segmentButtons.count else { return }
        
        let selectedButton = segmentButtons[selectedIndex]
        
        let textWidth = calculateTextWidth(for: selectedButton)
        let indicatorWidth = max(textWidth - 10, 20)
        
        indicatorView.snp.remakeConstraints { make in
            make.width.equalTo(indicatorWidth)
            make.height.equalTo(2)
            make.bottom.equalToSuperview()
            make.centerX.equalTo(selectedButton)
        }
    }
    
    private func calculateTextWidth(for button: UIButton) -> CGFloat {
        guard let title = button.title(for: .normal) else {
            return 20
        }
        
        let font = button.titleLabel?.font ?? UIFont.systemFont(ofSize: 16, weight: .regular)
        let attributes = [NSAttributedString.Key.font: font]
        let textSize = title.size(withAttributes: attributes)
        return textSize.width + 2
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateIndicatorPosition()
    }
} 
