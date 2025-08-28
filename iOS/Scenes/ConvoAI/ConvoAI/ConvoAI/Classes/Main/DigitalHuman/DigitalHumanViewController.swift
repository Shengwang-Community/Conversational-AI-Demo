//
//  DigitalHumanViewController.swift
//  BLEManager
//
//  Created by qinhui on 2025/7/3.
//

import Foundation
import Common
import UIKit

// MARK: - Data Model
struct DigitalHuman {
    static let closeTag = "close"
    let avatar: Avatar
    let isAvailable: Bool
    var isSelected: Bool
}

class DigitalHumanViewController: BaseViewController {
    
    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(DigitalHumanCell.self, forCellWithReuseIdentifier: DigitalHumanCell.identifier)
        collectionView.register(DigitalHumanCloseCell.self, forCellWithReuseIdentifier: DigitalHumanCloseCell.identifier)
        return collectionView
    }()
    
    // MARK: - Mock Data
    private var digitalHumans: [DigitalHuman] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
        setupUI()
        setupConstraints()
    }
    
    private func loadData() {
        guard let language = AppContext.preferenceManager()?.preference.language else {
            let closeCard = DigitalHuman(avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "", thumbImageUrl: "", bgImageUrl: ""), isAvailable: true, isSelected: true)
            digitalHumans.insert(closeCard, at: 0)
            return
        }
        
        guard let avatarIdsByLang = AppContext.preferenceManager()?.preference.preset?.avatarIdsByLang else {
            let closeCard = DigitalHuman(avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "", thumbImageUrl: "", bgImageUrl: ""), isAvailable: true, isSelected: true)
            digitalHumans.insert(closeCard, at: 0)
            return
        }
        
        guard let visibleAvatars = avatarIdsByLang[language.languageCode.stringValue()] else {
            let closeCard = DigitalHuman(avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "", thumbImageUrl: "", bgImageUrl: ""), isAvailable: true, isSelected: true)
            digitalHumans.insert(closeCard, at: 0)
            return
        }
        
        var selectedTag = false
        if let currentAvatar = AppContext.preferenceManager()?.preference.avatar {
            let avatars = visibleAvatars.map { avatar in
                let isSelected = avatar.avatarId == currentAvatar.avatarId
                if isSelected {
                    selectedTag = true
                }
                
                return DigitalHuman(avatar: avatar, isAvailable: true, isSelected: isSelected)
            }
            digitalHumans = avatars
        } else {
            let avatars = visibleAvatars.map { avatar in
                return DigitalHuman(avatar: avatar, isAvailable: true, isSelected: false)
            }
            digitalHumans = avatars
        }
        
        let closeCard = DigitalHuman(avatar: Avatar(vendor: "", avatarId: DigitalHuman.closeTag, avatarName: "", thumbImageUrl: "", bgImageUrl: ""), isAvailable: true, isSelected: !selectedTag)
        digitalHumans.insert(closeCard, at: 0)
    }
    
    private func setupUI() {
        navigationTitle = ResourceManager.L10n.Settings.digitalHuman
        view.addSubview(collectionView)
    }

    private func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(self.naviBar.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension DigitalHumanViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return digitalHumans.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let digitalHuman = digitalHumans[indexPath.item]
        
        if digitalHuman.avatar.avatarId == DigitalHuman.closeTag {
            // Use DigitalHumanCloseCell for close option
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DigitalHumanCloseCell.identifier, for: indexPath) as! DigitalHumanCloseCell
            cell.configure(with: digitalHuman)
            
            // Handle selection callback
            cell.onSelectionChanged = { [weak self] selectedDigitalHuman in
                self?.handleDigitalHumanSelection(selectedDigitalHuman)
            }
            
            return cell
        } else {
            // Use DigitalHumanCell for normal digital humans
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DigitalHumanCell.identifier, for: indexPath) as! DigitalHumanCell
            cell.configure(with: digitalHuman)
            
            // Handle selection callback
            cell.onSelectionChanged = { [weak self] selectedDigitalHuman in
                self?.handleDigitalHumanSelection(selectedDigitalHuman)
            }
            
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension DigitalHumanViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let leftRightPadding: CGFloat = 16 * 2 // left + right padding
        let spacing: CGFloat = 8 // inter-item spacing
        let availableWidth = collectionView.frame.width - leftRightPadding - spacing
        let itemWidth = availableWidth / 2
        
        let aspectRatio: CGFloat = 180.0 / 167.0
        let itemHeight = itemWidth * aspectRatio
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - Selection Handling
extension DigitalHumanViewController {
    private func handleDigitalHumanSelection(_ selectedDigitalHuman: DigitalHuman) {
        // Update selection state
        for i in 0..<digitalHumans.count {
            digitalHumans[i].isSelected = (digitalHumans[i].avatar.avatarId == selectedDigitalHuman.avatar.avatarId)
        }
        
        // Reload collection view to update UI
        collectionView.reloadData()
        
        print("Selected digital human: \(selectedDigitalHuman.avatar.avatarName), avatar id: \(selectedDigitalHuman.avatar.avatarId)")
        if selectedDigitalHuman.avatar.avatarId == DigitalHuman.closeTag {
            AppContext.preferenceManager()?.updateAvatar(nil)
        } else {
            AppContext.preferenceManager()?.updateAvatar(selectedDigitalHuman.avatar)
        }
    }
}
