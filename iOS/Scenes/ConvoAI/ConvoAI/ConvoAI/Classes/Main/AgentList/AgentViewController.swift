//
//  AgentListViewController.swift
//  ConvoAI
//
//  Created by HeZhengQing on 2024/07/25.
//

import UIKit
import Common
import SVProgressHUD
import IoT

public class AgentViewController: UIViewController {

    private lazy var menuButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_agent_info_list")?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = UIColor.themColor(named: "ai_icontext1")
        button.addTarget(self, action: #selector(onClickInformationButton), for: .touchUpInside)
        return button
    }()

    private lazy var titleView: UIStackView = {
        let titleImageView = UIImageView()
        titleImageView.image = UIImage.ag_named("ic_agent_detail_logo")
        titleImageView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = ResourceManager.L10n.Join.title
        titleLabel.textColor = UIColor.themColor(named: "ai_icontext1")
        titleLabel.font = .boldSystemFont(ofSize: 14)

        let stackView = UIStackView(arrangedSubviews: [titleImageView, titleLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center

        titleImageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
        return stackView
    }()

    private lazy var segmentedControl: CovSegmentedControl = {
        let items = [ResourceManager.L10n.AgentList.official, ResourceManager.L10n.AgentList.custom]
        let control = CovSegmentedControl(frame: .zero, buttonTitles: items)
        control.delegate = self
        return control
    }()

    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pvc.dataSource = self
        pvc.delegate = self
        return pvc
    }()
    
    private let officialAgentVC = OfficialAgentViewController()
    
    private let customAgentVC = CustomAgentViewController()

    private lazy var viewControllers: [UIViewController] = {
        return [officialAgentVC, customAgentVC]
    }()
    
    private var maxSegmentTop: CGFloat = 50
    private var minSegmentTop: CGFloat = 4
    private var maxSegmentWidth = UIScreen.main.bounds.width - 50
    private var minSegmentWidth: CGFloat = 184
    
    deinit {
        AppContext.loginManager()?.removeDelegate(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configDevMode()
        
        AppContext.loginManager()?.addDelegate(self)
        fetchLoginState()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    @objc func onClickInformationButton() {
        AgentInformationViewController.show(in: self)
    }
    
    func fetchLoginState() {
        let loginState = UserCenter.shared.isLogin()
        if loginState {
            LoginApiService.getUserInfo { error in
                if let err = error {
                    AppContext.loginManager()?.logout(reason: .sessionExpired)
                    SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                }
            }
        } else {
            LoginViewController.start(from: self)
        }
    }
    
    func addLog(_ txt: String) {
        ConvoAILogger.info(txt)
    }
    
    private func fetchIotPresetsIfNeeded() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            IoTEntrance.fetchPresetIfNeed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.themColor(named: "ai_fill7")
        view.addSubview(menuButton)
        view.addSubview(titleView)
        view.addSubview(segmentedControl)
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        if let scrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.delegate = self
        }
        if let firstViewController = viewControllers.first {
            pageViewController.setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
            if let vc = firstViewController as? OfficialAgentViewController {
                vc.scrollDelegate = self
            } else if let vc = firstViewController as? CustomAgentViewController {
                vc.scrollDelegate = self
            }
        }
    }

    private func setupConstraints() {
        menuButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(menuButton)
        }
        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(maxSegmentTop)
            make.centerX.equalToSuperview()
            make.width.equalTo(maxSegmentWidth)
            make.height.equalTo(36)
        }
        pageViewController.view.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(16)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    func agentScrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y

        let scrollableHeight = maxSegmentTop - minSegmentTop
        // Clamp offsetY to the range of the animation
        let clampedOffsetY = max(0, min(offsetY, scrollableHeight))
        // Calculate scroll progress (0 to 1)
        let scrollProgress = clampedOffsetY / scrollableHeight

        // Calculate new values based on scroll progress
        let newSegmentTop = maxSegmentTop - (maxSegmentTop - minSegmentTop) * scrollProgress
        let newSegmentWidth = maxSegmentWidth - (maxSegmentWidth - minSegmentWidth) * scrollProgress
        titleView.alpha = (1 - scrollProgress)
        segmentedControl.snp.updateConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(newSegmentTop)
            make.width.equalTo(newSegmentWidth)
        }
    }
}

extension AgentViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate, CovSegmentedControlDelegate, AgentScrollViewDelegate, UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // This is for the page view controller's horizontal scroll
        let pageWidth = view.bounds.width
        let offset = scrollView.contentOffset.x
        let progress = (offset - pageWidth) / pageWidth
        
        // Pass the progress to the segmented control to update its selector position
        if progress != 0 {
            segmentedControl.moveSelector(with: progress)
        }
    }
    
    func didChange(to index: Int) {
        let direction: UIPageViewController.NavigationDirection = index > (pageViewController.viewControllers?.first.flatMap { viewControllers.firstIndex(of: $0) } ?? 0) ? .forward : .reverse
        pageViewController.setViewControllers([viewControllers[index]], direction: direction, animated: true, completion: nil)
    }
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = viewControllers.firstIndex(of: viewController) else {
            return nil
        }
        let previousIndex = viewControllerIndex - 1
        guard previousIndex >= 0 else {
            return nil
        }
        return viewControllers[previousIndex]
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = viewControllers.firstIndex(of: viewController) else {
            return nil
        }
        let nextIndex = viewControllerIndex + 1
        guard nextIndex < viewControllers.count else {
            return nil
        }
        return viewControllers[nextIndex]
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed,
           let currentViewController = pageViewController.viewControllers?.first,
           let index = viewControllers.firstIndex(of: currentViewController) {
            if segmentedControl.selectedIndex != index {
                segmentedControl.selectedIndex = index
            }
            if let vc = currentViewController as? OfficialAgentViewController {
                vc.scrollDelegate = self
            } else if let vc = currentViewController as? CustomAgentViewController {
                vc.scrollDelegate = self
            }
        }
    }
}
// MARK: - Login
extension AgentViewController: LoginManagerDelegate {
    
    func userDidLogin() {
        fetchLoginState()
        officialAgentVC.fetchData()
        customAgentVC.fetchData()
    }
    
    func userDidLogout(reason: LogoutReason) {
        addLog("[Call] userDidLogout \(reason)")
        
        SVProgressHUD.showInfo(withStatus: ResourceManager.L10n.Login.sessionExpired)
        // Dismiss all view controllers and return to root
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.dismiss(animated: false, completion: nil)
        }
        self.navigationController?.popToRootViewController(animated: false)
        LoginViewController.start(from: self)
    }
}
// MARK: - DevMode
extension AgentViewController: DeveloperConfigDelegate {
    internal func configDevMode() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onClickLogo))
        titleView.isUserInteractionEnabled = true
        titleView.addGestureRecognizer(tapGesture)
        
        DeveloperConfig.shared.add(delegate: self)
    }
    
    @objc func onClickLogo() {
        DeveloperConfig.shared.countTouch()
    }
    
    public func devConfigDidSwitchServer(_ config: DeveloperConfig) {
        IoTEntrance.deleteAllPresets()
        AppContext.preferenceManager()?.deleteAllPresets()
        AppContext.loginManager()?.logout(reason: .sessionExpired)
        NotificationCenter.default.post(name: .EnvironmentChanged, object: nil, userInfo: nil)
    }
}
