//
//  BaseWebViewController.swift
//  ConvoAI
//
//  Created by qinhui on 2025/9/9.
//

import UIKit
import WebKit
import SVProgressHUD

class BaseWebViewController: BaseViewController {
    var url: String = ""

    private lazy var webView: WKWebView = {
        // Config WKWebView
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // Register JavaScript callback
        configuration.userContentController = userContentController
        configuration.applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"

        let view = WKWebView(frame: CGRectZero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        return view
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        loadContent()
    }
 
    private func setupUI() {
        view.addSubview(webView)
        
        webView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.top.equalTo(naviBar.snp.bottom)
        }
    }
    
    private func loadContent() {
        if let url = URL(string: url) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

extension BaseViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        SVProgressHUD.show()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        SVProgressHUD.show(withStatus: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SVProgressHUD.dismiss()
        
        webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
            if let title = result as? String {
                self?.naviBar.title = title
            }
        }
    }
}
