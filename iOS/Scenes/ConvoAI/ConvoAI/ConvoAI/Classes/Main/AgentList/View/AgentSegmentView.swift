//
//  AgentSegmentView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/10.
//

import UIKit
import Common
import SnapKit

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

protocol AgentSegmentViewDelegate: AnyObject {
    func agentSegmentView(_ segmentView: AgentSegmentView, didSelectIndex index: Int)
}

class SegmentItemView: UIView {
    
    // MARK: - UI Components
    lazy var button: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = .clear
        view.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        view.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        return view
    }()
    
    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    // MARK: - Properties
    private let configuration = AgentSegmentView.Configuration()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = UIColor.clear
        
        addSubview(iconView)
        addSubview(button)
    }
    
    private func setupConstraints() {
        button.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(4)
            make.right.equalTo(-4)
        }
        
        iconView.snp.makeConstraints { make in
            make.right.equalTo(-1)
            make.bottom.equalTo(-2)
            make.size.equalTo(CGSize(width: 16, height: 16))
        }
    }
    
    // MARK: - Public Methods
    func configure(title: String, icon: UIImage? = nil) {
        button.setTitle(title, for: .normal)
        
        if let icon = icon {
            iconView.image = icon
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
            iconView.image = nil
        }
    }
    
    func updateAppearance(isSelected: Bool) {
        if isSelected {
            button.titleLabel?.font = UIFont.systemFont(ofSize: configuration.selectedFontSize, weight: .semibold)
            iconView.isHidden = false
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: configuration.fontSize, weight: .medium)
            iconView.isHidden = true
        }
    }
    
    func setScale(_ scale: CGFloat) {
        transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}

class AgentSegmentView: UIView {
    
    // MARK: - Configuration
    struct Configuration {
        let normalScale: CGFloat = 1.0
        let selectedScale: CGFloat = 1.2
        let animationDuration: TimeInterval = 0.3
        let buttonHeight: CGFloat = 32
        let fontSize: CGFloat = 13
        let selectedFontSize: CGFloat = 16
    }
    
    // MARK: - Properties
    weak var delegate: AgentSegmentViewDelegate?
    
    private var titles: [String] = []
    private var selectedIndex: Int = 0
    private var segmentItems: [SegmentItemView] = []
    private let configuration = Configuration()
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.backgroundColor = UIColor.clear
        return scrollView
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.spacing = 16
        return stackView
    }()
    
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = UIColor.clear
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func configure(with titles: [String], selectedIndex: Int = 0) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        
        // Remove existing items
        segmentItems.forEach { $0.removeFromSuperview() }
        segmentItems.removeAll()
        
        // Create new items
        createSegmentItems()
        
        // Set initial selection
        updateSelection(animated: false)
    }
    
    func configure(with titles: [String], icons: [UIImage?]? = nil, selectedIndex: Int = 0) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        
        // Remove existing items
        segmentItems.forEach { $0.removeFromSuperview() }
        segmentItems.removeAll()
        
        // Create new items with icons
        createSegmentItems(with: icons)
        
        // Set initial selection
        updateSelection(animated: false)
    }
    
    func setSelectedIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < segmentItems.count else { return }
        
        selectedIndex = index
        updateSelection(animated: animated)
        
        // Scroll to center the selected item if needed
        scrollToCenter(itemIndex: index, animated: animated)
    }
    
    // MARK: - Private Methods
    private func createSegmentItems() {
        createSegmentItems(with: nil)
    }
    
    private func createSegmentItems(with icons: [UIImage?]?) {
        for (index, title) in titles.enumerated() {
            let icon = icons?[safe: index] ?? nil
            let item = createSegmentItem(title: title, icon: icon, index: index)
            segmentItems.append(item)
            stackView.addArrangedSubview(item)
        }
    }
    
    private func createSegmentItem(title: String, icon: UIImage?, index: Int) -> SegmentItemView {
        let item = SegmentItemView()
        item.configure(title: title, icon: icon)
        item.button.tag = index
        item.button.addTarget(self, action: #selector(segmentItemTapped(_:)), for: .touchUpInside)
        
        // Set item size constraints
        item.snp.makeConstraints { make in
            make.height.equalTo(configuration.buttonHeight)
        }
        
        return item
    }
    
    
    @objc private func segmentItemTapped(_ sender: UIButton) {
        let index = sender.tag
        
        // Don't do anything if already selected
        if index == selectedIndex {
            return
        }
        
        setSelectedIndex(index, animated: true)
        delegate?.agentSegmentView(self, didSelectIndex: index)
    }
    
    private func updateSelection(animated: Bool) {
        let animationDuration = animated ? configuration.animationDuration : 0
        
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: {
                for (index, item) in self.segmentItems.enumerated() {
                    let isSelected = index == self.selectedIndex
                    
                    // Update appearance
                    item.updateAppearance(isSelected: isSelected)
                    
                    // Update scale
                    let scale = isSelected ? self.configuration.selectedScale : self.configuration.normalScale
                    item.setScale(scale)
                }
            },
            completion: nil
        )
    }
    
    private func scrollToCenter(itemIndex: Int, animated: Bool) {
        guard itemIndex < segmentItems.count else { return }
        
        let item = segmentItems[itemIndex]
        let itemCenter = item.center.x + stackView.frame.origin.x
        let scrollViewCenter = scrollView.bounds.width / 2
        let offsetX = itemCenter - scrollViewCenter
        
        // Clamp offset to valid range
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let clampedOffsetX = max(0, min(offsetX, maxOffsetX))
        
        scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: animated)
    }
    
    // MARK: - Getters
    var currentSelectedIndex: Int {
        return selectedIndex
    }
    
    var currentSelectedTitle: String? {
        guard selectedIndex >= 0 && selectedIndex < titles.count else { return nil }
        return titles[selectedIndex]
    }
}
