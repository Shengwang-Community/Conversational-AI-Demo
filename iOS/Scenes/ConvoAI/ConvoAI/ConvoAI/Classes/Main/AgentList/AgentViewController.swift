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
    private lazy var segmentView: AgentSegmentView = {
        let view = AgentSegmentView()
        view.delegate = self
        let titles = [ResourceManager.L10n.AgentList.official, ResourceManager.L10n.AgentList.custom]
        let icons = [
            UIImage.ag_named("ic_segment_icon"),
            UIImage.ag_named("ic_segment_icon"),
            UIImage.ag_named("ic_segment_icon")
        ]
        view.configure(with: titles, icons: icons, selectedIndex: 0)
        return view
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
    
    deinit {
        AppContext.loginManager().removeDelegate(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        registerDelegate()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    @objc func onClickInformationButton() {
        // AgentInformationViewController removed - functionality moved to MineViewController
    }
    
    func registerDelegate() {
        AppContext.loginManager().addDelegate(self)
        DeveloperConfig.shared.add(delegate: self)
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
        view.addSubview(segmentView)
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        if let firstViewController = viewControllers.first {
            pageViewController.setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
        }
    }

    private func setupConstraints() {
        segmentView.snp.makeConstraints { make in
            make.left.equalTo(26)
            make.right.equalTo(-26)
            make.top.equalTo(self.view.safeAreaLayoutGuide).offset(25)
            make.height.equalTo(32)
        }
        
        pageViewController.view.snp.makeConstraints { make in
            make.top.equalTo(segmentView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide)
        }
    }
}

extension AgentViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
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
            if segmentView.currentSelectedIndex != index {
                segmentView.setSelectedIndex(index)
            }
        }
    }
}
// MARK: - Login
extension AgentViewController: LoginManagerDelegate {
    
    func userDidLogin() {
        officialAgentVC.fetchData()
        customAgentVC.fetchData()
    }
}
// MARK: - DevMode
extension AgentViewController: DeveloperConfigDelegate {
    public func devConfigDidSwitchServer(_ config: DeveloperConfig) {
        IoTEntrance.deleteAllPresets()
        AppContext.loginManager().logout(reason: .resetScene)
        NotificationCenter.default.post(name: .EnvironmentChanged, object: nil, userInfo: nil)
    }
}

extension AgentViewController: AgentSegmentViewDelegate {
    func agentSegmentView(_ segmentView: AgentSegmentView, didSelectIndex index: Int) {
        let direction: UIPageViewController.NavigationDirection = index > (pageViewController.viewControllers?.first.flatMap { viewControllers.firstIndex(of: $0) } ?? 0) ? .forward : .reverse
        pageViewController.setViewControllers([viewControllers[index]], direction: direction, animated: true, completion: nil)
    }
}
