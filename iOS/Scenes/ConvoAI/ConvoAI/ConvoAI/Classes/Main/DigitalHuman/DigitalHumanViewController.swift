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
    let id: String
    let name: String
    let avatarImage: String
    let isAvailable: Bool
    var isSelected: Bool
    
    static let closeOption = DigitalHuman(
        id: "close",
        name: ResourceManager.L10n.Settings.digitalHumanClosed,
        avatarImage: "",
        isAvailable: true,
        isSelected: false
    )
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
        return collectionView
    }()
    
    // MARK: - Mock Data
    private var digitalHumans: [DigitalHuman] = [
        DigitalHuman.closeOption,
        DigitalHuman(
            id: "shahala",
            name: "沙哈拉",
            avatarImage: "avatar_shahala",
            isAvailable: true,
            isSelected: true
        ),
        DigitalHuman(
            id: "xiaoli",
            name: "小丽",
            avatarImage: "avatar_xiaoli",
            isAvailable: true,
            isSelected: false
        ),
        DigitalHuman(
            id: "david",
            name: "David",
            avatarImage: "avatar_david",
            isAvailable: true,
            isSelected: false
        ),
        DigitalHuman(
            id: "anna",
            name: "Anna",
            avatarImage: "avatar_anna",
            isAvailable: true,
            isSelected: false
        ),
        DigitalHuman(
            id: "mike",
            name: "Mike",
            avatarImage: "avatar_mike",
            isAvailable: true,
            isSelected: false
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DigitalHumanCell.identifier, for: indexPath) as! DigitalHumanCell
        
        let digitalHuman = digitalHumans[indexPath.item]
        cell.configure(with: digitalHuman)
        
        // Handle selection callback
        cell.onSelectionChanged = { [weak self] selectedDigitalHuman in
            self?.handleDigitalHumanSelection(selectedDigitalHuman)
        }
        
        return cell
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
            digitalHumans[i].isSelected = (digitalHumans[i].id == selectedDigitalHuman.id)
        }
        
        // Reload collection view to update UI
        collectionView.reloadData()
        
        // TODO: Save selection to preferences
        print("Selected digital human: \(selectedDigitalHuman.name)")
    }
}
