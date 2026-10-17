import SwiftUI
import WebKit

/// WKWebView 封装：加载第三方支付跳转页
struct PayWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        let req = URLRequest(url: url)
        web.load(req)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
