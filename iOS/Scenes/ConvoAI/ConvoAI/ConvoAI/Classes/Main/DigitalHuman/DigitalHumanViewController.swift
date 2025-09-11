//
//  DigitalHumanViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/11.
//

import Foundation
import Common
import UIKit

// MARK: - Data Model
class DigitalHuman {
    static let closeTag = "close"
    let avatar: Avatar
    let isAvailable: Bool
    var isSelected: Bool
    
    init(avatar: Avatar, isAvailable: Bool, isSelected: Bool) {
        self.avatar = avatar
        self.isAvailable = isAvailable
        self.isSelected = isSelected
    }
}

// MARK: - Group Data Model
class DigitalHumanGroup {
    let groupName: String
    let vendor: String
    var digitalHumans: [DigitalHuman]
    let isDefaultGroup: Bool // For "close" option
    
    init(groupName: String, vendor: String, digitalHumans: [DigitalHuman], isDefaultGroup: Bool) {
        self.groupName = groupName
        self.vendor = vendor
        self.digitalHumans = digitalHumans
        self.isDefaultGroup = isDefaultGroup
    }
}

class DigitalHumanViewController: BaseViewController {
    
    // MARK: - UI Components
    private lazy var segmentView: DigitalHumanSegmentView = {
        let view = DigitalHumanSegmentView()
        view.delegate = self
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.bounces = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Data
    private var digitalHumanGroups: [DigitalHumanGroup] = []
    private var groupViews: [DigitalHumanGroupView] = []
    private var currentPageIndex: Int = 0
    private var isScrollViewConstraintsSetup: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
        setupUI()
        setupConstraints()
    }
    
    private func loadData() {
        guard
            let language = AppContext.preferenceManager()?.preference.language,
            let avatarIdsByLang = AppContext.preferenceManager()?.preference.preset?.avatarIdsByLang,
            let visibleAvatars = avatarIdsByLang[language.languageCode.stringValue()]
        else {
            createDefaultGroup()
            return
        }
        // Group avatars by vendor
        let groupedAvatars = Dictionary(grouping: visibleAvatars) { $0.vendor }
        
        // Create close digital human (shared across all groups)
        let currentAvatar = AppContext.preferenceManager()?.preference.avatar
        let hasSelectedAvatar = currentAvatar != nil
        let closeDigitalHuman = DigitalHuman(
            avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "关闭", thumbImageUrl: nil, bgImageUrl: nil),
            isAvailable: true,
            isSelected: !hasSelectedAvatar
        )
        
        // Create groups
        var groups: [DigitalHumanGroup] = []
        
        // 1. Create "All" group (first group)
        let allDigitalHumans = visibleAvatars.map { avatar in
            let isSelected = avatar.avatarId == currentAvatar?.avatarId
            return DigitalHuman(avatar: avatar, isAvailable: true, isSelected: isSelected)
        }
        
        // Add close option as first item in "All" group
        let allGroupDigitalHumans = [closeDigitalHuman] + allDigitalHumans
        let allGroup = DigitalHumanGroup(
            groupName: "全部",
            vendor: "all",
            digitalHumans: allGroupDigitalHumans,
            isDefaultGroup: false
        )
        groups.append(allGroup)
        
        // 2. Create vendor-specific groups
        for (vendor, avatars) in groupedAvatars {
            let vendor = vendor ?? "other"
            let vendorDigitalHumans = avatars.map { avatar in
                let isSelected = avatar.avatarId == currentAvatar?.avatarId
                return DigitalHuman(avatar: avatar, isAvailable: true, isSelected: isSelected)
            }
            
            // Add close option as first item in each vendor group
            let vendorGroupDigitalHumans = [closeDigitalHuman] + vendorDigitalHumans
            let vendorGroup = DigitalHumanGroup(
                groupName: vendor,
                vendor: vendor,
                digitalHumans: vendorGroupDigitalHumans,
                isDefaultGroup: false
            )
            groups.append(vendorGroup)
        }
        
        // Sort vendor groups by name (keep "All" group first)
        let sortedVendorGroups = groups.dropFirst().sorted { $0.vendor < $1.vendor }
        groups = [allGroup] + sortedVendorGroups
        
        digitalHumanGroups = groups
        setupGroupViews()
        setupSegmentView()
        setupScrollView()
    }
    
    private func createDefaultGroup() {
        // Create close digital human
        let closeDigitalHuman = DigitalHuman(
            avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "关闭", thumbImageUrl: nil, bgImageUrl: nil),
            isAvailable: true,
            isSelected: true
        )
        
        // Create "All" group with only close option
        let allGroup = DigitalHumanGroup(
            groupName: "全部",
            vendor: "all",
            digitalHumans: [closeDigitalHuman],
            isDefaultGroup: false
        )
        
        digitalHumanGroups = [allGroup]
        setupGroupViews()
        setupSegmentView()
        setupScrollView()
    }
    
    private func setupGroupViews() {
        groupViews.removeAll()
        
        for group in digitalHumanGroups {
            let groupView = DigitalHumanGroupView()
            groupView.delegate = self
            groupView.configure(with: group)
            groupViews.append(groupView)
        }
    }
    
    private func setupSegmentView() {
        let segmentNames = digitalHumanGroups.map { $0.groupName }
        segmentView.setSegments(segmentNames)
    }
    
    private func setupScrollView() {
        guard !groupViews.isEmpty else { return }
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add all group views to content view
        for groupView in groupViews {
            contentView.addSubview(groupView)
        }
        
        // Set initial page
        currentPageIndex = 0
        
        // Reset constraint setup flag
        isScrollViewConstraintsSetup = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Only update constraints if scroll view has a valid frame and constraints haven't been setup yet
        if scrollView.frame.width > 0 && !isScrollViewConstraintsSetup {
            updateScrollViewContentSize()
            isScrollViewConstraintsSetup = true
        }
    }
    
    private func updateScrollViewContentSize() {
        guard !groupViews.isEmpty else { return }
        
        let pageWidth = scrollView.frame.width
        let totalWidth = pageWidth * CGFloat(groupViews.count)
        
        // Use remakeConstraints to avoid constraint update issues
        contentView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalTo(totalWidth)
        }
        
        // Update group view constraints
        for (index, groupView) in groupViews.enumerated() {
            groupView.snp.remakeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(pageWidth)
                make.height.equalToSuperview()
                make.left.equalToSuperview().offset(CGFloat(index) * pageWidth)
            }
        }
    }
    
    private func setupUI() {
        navigationTitle = ResourceManager.L10n.Settings.digitalHuman
        view.addSubview(segmentView)
    }

    private func setupConstraints() {
        segmentView.snp.makeConstraints { make in
            make.top.equalTo(self.naviBar.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(36)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(segmentView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalTo(scrollView) // Set initial width constraint
        }
    }
}

// MARK: - DigitalHumanSegmentViewDelegate
extension DigitalHumanViewController: DigitalHumanSegmentViewDelegate {
    func digitalHumanSegmentView(_ view: DigitalHumanSegmentView, didSelectSegmentAt index: Int) {
        guard index >= 0 && index < groupViews.count else { return }
        
        let pageWidth = scrollView.frame.width
        let targetOffset = CGPoint(x: CGFloat(index) * pageWidth, y: 0)
        
        scrollView.setContentOffset(targetOffset, animated: true)
        currentPageIndex = index
    }
}

// MARK: - UIScrollViewDelegate
extension DigitalHumanViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPageIndex()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCurrentPageIndex()
    }
    
    private func updateCurrentPageIndex() {
        let pageWidth = scrollView.frame.width
        let currentOffset = scrollView.contentOffset.x
        let newPageIndex = Int(round(currentOffset / pageWidth))
        
        if newPageIndex != currentPageIndex && newPageIndex >= 0 && newPageIndex < groupViews.count {
            currentPageIndex = newPageIndex
            segmentView.selectSegment(at: currentPageIndex)
        }
    }
}

// MARK: - DigitalHumanGroupViewDelegate
extension DigitalHumanViewController: DigitalHumanGroupViewDelegate {
    func digitalHumanGroupView(_ view: DigitalHumanGroupView, didSelectDigitalHuman digitalHuman: DigitalHuman) {
        handleDigitalHumanSelection(digitalHuman)
    }
}

// MARK: - Selection Handling
extension DigitalHumanViewController {
    private func handleDigitalHumanSelection(_ selectedDigitalHuman: DigitalHuman) {
        // Update selection state across all groups
        // Since DigitalHuman is now a class, we can directly modify the isSelected property
        for group in digitalHumanGroups {
            for digitalHuman in group.digitalHumans {
                digitalHuman.isSelected = (digitalHuman.avatar.avatarId == selectedDigitalHuman.avatar.avatarId)
            }
        }
        
        // Update all group views to reflect the changes
        for groupView in groupViews {
            groupView.collectionView.reloadData()
        }
        
        print("Selected digital human: \(selectedDigitalHuman.avatar.avatarName), avatar id: \(selectedDigitalHuman.avatar.avatarId)")
        if selectedDigitalHuman.avatar.avatarId == DigitalHuman.closeTag {
            AppContext.preferenceManager()?.updateAvatar(nil)
        } else {
            AppContext.preferenceManager()?.updateAvatar(selectedDigitalHuman.avatar)
        }
    }
}
