//
//  AgentSelectTableView.swift
//  Agent
//
//  Created by HeZhengQing on 2024/10/1.
//

import UIKit
import Common

struct AgentSelectTableItem {
    let title: String
    let subTitle: String
}

class AgentSelectTableView: UIView {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var dataSource = [AgentSelectTableItem]()
    private var onSelected: ((Int) -> Void)?
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    init(items: [AgentSelectTableItem], selected: @escaping ((Int) -> Void)) {
        super.init(frame: .zero) 
        dataSource = items
        onSelected = selected
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func getWith() -> CGFloat {
        return 250.0
    }
    
    func getHeight() -> CGFloat {
        tableView.layoutIfNeeded()
        let contentHeight = tableView.contentSize.height
        return min(contentHeight, 300)
    }

    private func setup() {
        self.layerCornerRadius = 12
        backgroundColor = UIColor.themColor(named: "ai_line1")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(cellWithClass: AgentSettingSubOptionCell.self)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        
        tableView.bounces = false
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setSelectedIndex(_ index: Int) {
        selectedIndex = index
        tableView.reloadData()
    }
}
// MARK: - UITableViewDelegate
extension AgentSelectTableView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: AgentSettingSubOptionCell.self)
        let item = dataSource[indexPath.row]
        cell.configure(with: item.title, subtitle: item.subTitle, isSelected: indexPath.row == selectedIndex)
        cell.bottomLine.isHidden = (indexPath.row == dataSource.count - 1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(UITableView.automaticDimension, 56)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndex = indexPath.row
        tableView.reloadData()
        onSelected?(indexPath.row)
    }
}
