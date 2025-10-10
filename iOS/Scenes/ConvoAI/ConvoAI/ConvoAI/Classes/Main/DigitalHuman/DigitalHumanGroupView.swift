//
//  DigitalHumanGroupView.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/11.
//

import UIKit
import Common
import SnapKit

protocol DigitalHumanGroupViewDelegate: AnyObject {
    func digitalHumanGroupView(_ view: DigitalHumanGroupView, didSelectDigitalHuman digitalHuman: DigitalHuman)
}

class DigitalHumanGroupView: UIView {
    
    // MARK: - Properties
    weak var delegate: DigitalHumanGroupViewDelegate?
    private var group: DigitalHumanGroup?
    
    // MARK: - UI Components
    public lazy var collectionView: UICollectionView = {
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
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        backgroundColor = .clear
        addSubview(collectionView)
    }
    
    private func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func configure(with group: DigitalHumanGroup) {
        self.group = group
        collectionView.reloadData()
    }
    
    func updateSelection(for selectedDigitalHuman: DigitalHuman) {
        // Since DigitalHuman is now a class, the selection state is already updated
        // in the main controller, we just need to reload the UI
        collectionView.reloadData()
    }
    
    func getCurrentGroup() -> DigitalHumanGroup? {
        return group
    }
}

// MARK: - UICollectionViewDataSource
extension DigitalHumanGroupView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return group?.digitalHumans.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let group = group,
              indexPath.item < group.digitalHumans.count else {
            return UICollectionViewCell()
        }
        
        let digitalHuman = group.digitalHumans[indexPath.item]
        
        if digitalHuman.avatar.avatarId == DigitalHuman.closeTag {
            // Use DigitalHumanCloseCell for close option
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DigitalHumanCloseCell.identifier, for: indexPath) as! DigitalHumanCloseCell
            cell.configure(with: digitalHuman)
            
            // Handle selection callback
            cell.onSelectionChanged = { [weak self] selectedDigitalHuman in
                self?.delegate?.digitalHumanGroupView(self!, didSelectDigitalHuman: selectedDigitalHuman)
            }
            
            return cell
        } else {
            // Use DigitalHumanCell for normal digital humans
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DigitalHumanCell.identifier, for: indexPath) as! DigitalHumanCell
            cell.configure(with: digitalHuman)
            
            // Handle selection callback
            cell.onSelectionChanged = { [weak self] selectedDigitalHuman in
                self?.delegate?.digitalHumanGroupView(self!, didSelectDigitalHuman: selectedDigitalHuman)
            }
            
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension DigitalHumanGroupView: UICollectionViewDelegateFlowLayout {
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
