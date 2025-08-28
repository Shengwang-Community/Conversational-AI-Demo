//
//  File.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/2/20.
//

import UIKit
@preconcurrency import WebKit
import SVProgressHUD
import Common

class CustomNavigationView: UIView {
    
    lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_agent_setting_back"), for: .normal)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .white
        
        addSubview(backButton)
        addSubview(titleLabel)
        
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(44)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(-22)
        }
    }
    
    func setTitle(_ title: String?) {
        titleLabel.text = title
    }
}

@objc class SSOWebViewController: UIViewController {
    private lazy var naviBar: CustomNavigationView = {
        let view = CustomNavigationView()
        view.setTitle(ResourceManager.L10n.Conversation.appName)
        view.backgroundColor = UIColor.themColor(named: "ai_fill4")
        view.backButton.addTarget(self, action: #selector(onClickBack), for: .touchUpInside)
        return view
    }()

    var urlString: String = ""
    
    private lazy var ssoWebView: WKWebView = {
        // Config WKWebView
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // Register JavaScript callback
        userContentController.add(self, name: "handleResponse")
        configuration.userContentController = userContentController
        configuration.applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"

        let view = WKWebView(frame: CGRectZero, configuration: configuration)
        view.navigationDelegate = self
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
    
    var completionHandler: ((String?) -> Void)?
    
    lazy var emptyView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        SVProgressHUD.setOffsetFromCenter(UIOffset(horizontal: 0, vertical: 0))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SVProgressHUD.dismiss()
        SVProgressHUD.setOffsetFromCenter(UIOffset(horizontal: 0, vertical: 180))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            ssoWebView.load(request)
        }
    }
    
    @objc func onClickBack() {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func setupUI() {
        view.addSubview(naviBar)
        view.addSubview(ssoWebView)
        view.addSubview(emptyView)
        
        let topInset = UIWindow.safeAreaInsets.top
        naviBar.snp.makeConstraints { make in
            make.height.equalTo(topInset + 64)
            make.left.right.top.equalTo(0)
        }
        
        ssoWebView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(naviBar.snp.bottom)
        }
        
        emptyView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(naviBar.snp.bottom)
        }
        
        emptyView.isHidden = true
    }
    
    func addLog(_ txt: String) {
        ConvoAILogger.info(txt)
    }
    
    // MARK: - JavaScript Injection
    private func injectJavaScript() {
        let jsCode = """
        (function() {
            // Get the text content of the page
            var jsonResponse = document.body.innerText; // Assume JSON data is in the body of the page
            // Parse the JSON data
            try {
                var jsonData = JSON.parse(jsonResponse); // Parse it into a JSON object
                // Check if the code is 0
                if (jsonData.code === 0) {
                    // Call the iOS interface and pass the token
                    window.webkit.messageHandlers.handleResponse.postMessage(jsonData.data.token);
                } else {
                    // If the code is not 0, return the error message
                    window.webkit.messageHandlers.handleResponse.postMessage("Error " + jsonData.msg);
                }
            } catch (e) {
                // Handle JSON parsing errors
                window.webkit.messageHandlers.handleResponse.postMessage("Error " + e.message);
            }
        })();
        """
        
        ssoWebView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    @objc static func clearWebViewCache() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { }
        
        let dataStore = URLCache.shared
        dataStore.removeAllCachedResponses()

        
        let cookieStorage = HTTPCookieStorage.shared
        for cookie in cookieStorage.cookies ?? [] {
            cookieStorage.deleteCookie(cookie)
        }
    }
}

// MARK: - WKNavigationDelegate
extension SSOWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        SVProgressHUD.show()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("v1/convoai/sso/callback") && !url.absoluteString.contains("redirect_uri") {
                emptyView.isHidden = false
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        SVProgressHUD.show(withStatus: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SVProgressHUD.dismiss()
        webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
            if let title = result as? String {
                self?.naviBar.setTitle(title)
            }
        }
        injectJavaScript()
    }
}

// MARK: - WKScriptMessageHandler
extension SSOWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "handleResponse" {
            if let response = message.body as? String {
                self.addLog("SSO response: \(response)")
                if !response.hasPrefix("Error") {
                    let token = response
                    let model = LoginModel()
                    model.token = token
                    AppContext.loginManager()?.updateUserInfo(userInfo: model)
                    self.navigationController?.dismiss(animated: true)
                } else {
                    completionHandler?(nil)
                }
            }
        }
    }
}

extension UIWindow {
    static var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 15.0, *) {
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            let window = scene?.windows.first(where: { $0.isKeyWindow })
            return window?.safeAreaInsets ?? .zero
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero
        }
    }
}
