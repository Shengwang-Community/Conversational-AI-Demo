//
//  MainTabViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2025/9/1.
//

import UIKit
import Common
import SVProgressHUD

public class MainTabBarController: UITabBarController {
    
    private lazy var toolBox = ToolBoxApiManager()
    
    deinit {
        AppContext.loginManager().removeDelegate(self)
    }
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        configureTabBarAppearance()
        
        AppContext.loginManager().addDelegate(self)
        fetchLoginState()
    }
    
    func fetchLoginState() {
        let loginState = UserCenter.shared.isLogin()
        if loginState {
            LoginApiService.getUserInfo { [weak self] error in
                if let err = error {
                    AppContext.loginManager().logout(reason: .sessionExpired)
                    SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                    return
                }
                self?.mayGenerateName()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                if let self = self, self.view.window != nil {
                    LoginViewController.start(from: self)
                }
            }
        }
    }
    
    private func mayGenerateName() {
        guard
            let user = UserCenter.user,
            user.nickname.isEmpty
        else { return }
        user.nickname = MainTabBarController.generateRandomNickname()
        toolBox.updateUserInfo(
            nickname: user.nickname,
            gender: user.gender,
            birthday: user.birthday,
            bio: user.bio,
            success: { response in
                AppContext.loginManager().updateUserInfo(userInfo: user)
            },
            failure: { error in
            }
        )
    }
    
    // MARK: - Setup Methods
    private func setupViewControllers() {
        // Create view controllers
        let agentsVC = createAgentsViewController()
        let mineVC = createMineViewController()
        
        // Set view controllers directly to use system tab bar
        viewControllers = [agentsVC, mineVC]
        
        // Configure tab bar items
        configureTabBarItems()
    }
    
    private func configureTabBarItems() {
        // Configure tab bar items with icons only, no titles
        if let agentsVC = viewControllers?[0] {
            agentsVC.tabBarItem = UITabBarItem(
                title: nil,
                image: UIImage.ag_named("ic_tabbar_home_n")?.withRenderingMode(.alwaysOriginal),
                selectedImage: UIImage.ag_named("ic_tabbar_home_s")?.withRenderingMode(.alwaysOriginal)
            )
            // Adjust icon position to center
            agentsVC.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
        }
        
        if let mineVC = viewControllers?[1] {
            mineVC.tabBarItem = UITabBarItem(
                title: nil,
                image: UIImage.ag_named("ic_tabbar_mine_n")?.withRenderingMode(.alwaysOriginal),
                selectedImage: UIImage.ag_named("ic_tabbar_mine_s")?.withRenderingMode(.alwaysOriginal)
            )
            // Adjust icon position to center
            mineVC.tabBarItem.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
        }
    }
    
    private func configureTabBarAppearance() {
        // Configure tab bar appearance for iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.themColor(named: "ai_fill1")
            
            // Remove top border line
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
            
            // Configure item appearance - no title text and center icons
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [:]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [:]
            
            // Center the icons vertically
            appearance.stackedLayoutAppearance.normal.iconColor = .clear
            appearance.stackedLayoutAppearance.selected.iconColor = .clear
            
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        } else {
            // Fallback for iOS 14 and below
            tabBar.shadowImage = UIImage()
            tabBar.backgroundImage = UIImage()
        }
        
        // Remove top border line for all iOS versions
        tabBar.shadowImage = UIImage()
        tabBar.backgroundImage = UIImage()
        
        // Additional icon positioning adjustments
        tabBar.itemPositioning = .centered
    }
    
    // MARK: - View Controller Creation
    private func createAgentsViewController() -> UIViewController {
        // Use existing AgentViewController
        let agentsVC = AgentViewController()
        let navController = UINavigationController(rootViewController: agentsVC)
        navController.navigationBar.isHidden = true
        
        return navController
    }
    
    private func createMineViewController() -> UIViewController {
        // Create a placeholder for Mine functionality
        let mineVC = MineViewController()
        let navController = UINavigationController(rootViewController: mineVC)
        navController.navigationBar.isHidden = true
        
        return navController
    }
}

extension MainTabBarController: LoginManagerDelegate {
    
    func userDidLogin() {
        fetchLoginState()
    }
    
    func userDidLogout(reason: LogoutReason) {
        ConvoAILogger.info("[Call] userDidLogout \(reason)")
        switch reason {
        case .userInitiated:
            SSOWebViewController.clearWebViewCache()
        case .sessionExpired:
            SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Login.sessionExpired)
            SSOWebViewController.clearWebViewCache()
        case .resetScene:
        }
        // Dismiss all view controllers and return to root
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: false, completion: nil)
        }
        // Pop all view controllers in each tab's navigation stack to root
        if let viewControllers = self.viewControllers {
            for case let nav as UINavigationController in viewControllers {
                nav.popToRootViewController(animated: false)
            }
        }
        // Return to the first tab before showing the login view
        self.selectedIndex = 0
        DispatchQueue.main.async { [weak self] in
            if let self = self, self.view.window != nil {
                LoginViewController.start(from: self)
            }
        }
    }
}

// MARK: - Name Generation
extension MainTabBarController {
    
    /// Generate a random nickname using adjective + noun combination
    /// Used when user first logs in and has no nickname
    static func generateRandomNickname() -> String {
        // Use localized strings for adjectives and nouns, split by comma
        let adjectives = ResourceManager.L10n.Mine.nicknameAdjectives.components(separatedBy: ",")
        let nouns = ResourceManager.L10n.Mine.nicknameNouns.components(separatedBy: ",")
        
        let randomAdjective = adjectives.randomElement() ?? ""
        let randomNoun = nouns.randomElement() ?? ""
        
        return "\(randomAdjective)\(randomNoun)"
    }
}
