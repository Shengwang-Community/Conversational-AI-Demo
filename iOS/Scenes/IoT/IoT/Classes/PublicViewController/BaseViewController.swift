//
//  BaseViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/4.
//

import UIKit

class BaseViewController: UIViewController {
    let naviBar = NavigationBar()
    
    var navigationTitle: String? {
        didSet {
            naviBar.title = navigationTitle
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.themColor(named: "ai_fill1")
        configCustomNaviBar()
    }
    
    private func configCustomNaviBar() {
        naviBar.backgroundColor = UIColor.themColor(named: "ai_fill1")
        view.addSubview(naviBar)
        
        // Hide system navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Setup back button if not root view controller
        if navigationController?.viewControllers.count ?? 0 > 1 {
            naviBar.setLeftButtonTarget(
                self,
                action: #selector(navigationBackButtonTapped),
                image: UIImage.ag_named("ic_base_back_icon")
            )            
        }
    }
    
    func addLog(_ txt: String) {
        IoTLogger.info(txt)
    }
    
    @objc func navigationBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func navigationRightButtonTapped() {}
}
