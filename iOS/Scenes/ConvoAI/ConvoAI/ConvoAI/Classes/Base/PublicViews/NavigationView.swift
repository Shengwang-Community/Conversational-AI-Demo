//
//  NavigationView.swift
//  ConvoAI
//
//  Created by qinhui on 2025/3/4.
//

import UIKit
import Common

extension UIApplication {
    static var kWindow: UIWindow? {
        // Get connected scenes
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
            // Keep only active scenes, onscreen and visible to the user
                .filter { $0.activationState == .foregroundActive }
            // Keep only the first `UIWindowScene`
                .first(where: { $0 is UIWindowScene })
            // Get its associated windows
                .flatMap({ $0 as? UIWindowScene })?.windows
            // Finally, keep only the key window
                .first(where: \.isKeyWindow)
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}

struct Screen {
    static let width = UIScreen.main.bounds.width
    static let height = UIScreen.main.bounds.height
    static var kNavHeight: CGFloat {
        44 + statusHeight()
    }
    
    static func safeHeight() -> CGFloat {
        guard let safeInserts = UIApplication.kWindow?.safeAreaInsets else {
            return 0
        }
        return height - safeInserts.top - safeInserts.bottom
    }
    
    static func statusHeight() -> CGFloat {
        var height: CGFloat = 0.0
        if #available(iOS 13.0, *) {
            let statusBarManager = UIApplication.kWindow?.windowScene?.statusBarManager
            height = statusBarManager?.statusBarFrame.height ?? 44

        } else {
            height = UIApplication.shared.statusBarFrame.height
        }

        return height
    }
    
    static func safeAreaBottomHeight() -> CGFloat {
        guard let safeInserts = UIApplication.kWindow?.safeAreaInsets else {
            return 0
        }
        return safeInserts.bottom
    }

    static func safeAreaTopHeight() -> CGFloat {
        guard let safeInserts = UIApplication.shared.windows.first?.safeAreaInsets else {
            return 0
        }
        
        if safeInserts.top == 0 {
            return 32
        }
        return safeInserts.top
    }
}

struct BarButtonItem {
    var title: String?
    var image: UIImage?
    weak var target: AnyObject?
    var action: Selector
}


class NavigationBar: UIView {
    
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    var rightItems: [BarButtonItem]? {
        didSet {
            addRightBarButtonItems(rightItems)
        }
    }
    
    var leftItems: [BarButtonItem]? {
        didSet {
            addLeftBarButtonItems(leftItems)
        }
    }
    
    private var leftButtons = [UIButton]()
    private var rightButtons = [UIButton]()
    
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        addSubview(titleLabel)
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return titleLabel
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: Screen.width, height: Screen.safeAreaTopHeight() + 44)
        self.backgroundColor = UIColor.themColor(named: "ai_fill1")
        createSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createSubviews(){
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-20)
            make.centerX.equalToSuperview()
        }
        
        setLeftButtonTarget(self, action: #selector(didClickLeftButtonAction))
    }
    
    func setRightButtonTarget(_ target: AnyObject, action: Selector, image: UIImage? = nil, title: String? = nil) {
        self.rightItems = nil
        let item = BarButtonItem(title: title, image: image, target: target, action: action)
        self.rightItems = [item]
    }
    
    func setLeftButtonTarget(_ target: AnyObject, action: Selector, image: UIImage? = UIImage.ag_named("ic_base_back_icon"), title: String? = nil ) {
        self.leftItems = nil
        let item = BarButtonItem(title: title, image: image, target: target, action: action)
        self.leftItems = [item]
    }
    
   
}

extension NavigationBar {
    @objc private func didClickLeftButtonAction(){
        currentNavigationController()?.popViewController(animated: true)
    }
    
    private func currentNavigationController() -> UINavigationController? {
        var nextResponder = next
        while (nextResponder is UINavigationController || nextResponder == nil) == false {
            nextResponder = nextResponder?.next
        }
        return nextResponder as? UINavigationController
    }
    
    private func addRightBarButtonItems(_ items: [BarButtonItem]?) {
        if items == nil {
            for button in rightButtons {
                button.removeFromSuperview()
            }
            return
        }
        var firstButton: UIButton?
        for item in items! {
            let button = createBarButton(item: item)
            addSubview(button)
            rightButtons.append(button)
            button.snp.makeConstraints { make in
                if firstButton == nil {
                    firstButton = button
                    make.right.equalTo(-20)
                }else{
                    make.right.equalTo(firstButton!.snp.left).offset(-25)
                }
                make.centerY.equalTo(titleLabel)
            }
        }
    }
    
    private func addLeftBarButtonItems(_ items: [BarButtonItem]?) {
        if items == nil {
            for button in leftButtons {
                button.removeFromSuperview()
            }
            return
        }
        var firstButton: UIButton?
        for item in items! {
            let button = createBarButton(item: item)
            addSubview(button)
            leftButtons.append(button)
            button.snp.makeConstraints { make in
                if firstButton == nil {
                    firstButton = button
                    make.left.equalTo(20)
                }else{
                    make.left.equalTo(firstButton!.snp.right).offset(25)
                }
                make.centerY.equalTo(titleLabel)
            }
        }
    }
    
    private func createBarButton(item: BarButtonItem) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(item.title, for: .normal)
        button.setImage(item.image, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.addTarget(item.target, action: item.action, for: .touchUpInside)
        return button
    }
}

