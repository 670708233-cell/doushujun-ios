import SwiftUI
import WebKit

/// 支付页：内置 WebView 打开第三方支付链接 + 复制链接/Safari 打开 + 支付结果轮询
struct PayView: View {
    let orderNo: String
    let payUrl: String
    let onFinished: (_ paid: Bool) -> Void

    @EnvironmentObject private var store: UserStore
    @Environment(\.openURL) private var openURL

    @State private var isPolling = false
    @State private var pollMessage = ""
    @State private var toast: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("请在新打开的页面完成支付")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("支付完成后点击底部「我已完成支付」按钮")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(red: 0.12, green: 0.17, blue: 0.3))

                if let url = URL(string: payUrl) {
                    PayWebView(url: url)
                        .frame(maxHeight: .infinity)
                } else {
                    Text("支付链接无效")
                        .foregroundColor(.white)
                        .frame(maxHeight: .infinity)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: copyLink) {
                            Label("复制链接", systemImage: "doc.on.doc")
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }

                        Button(action: openInSafari) {
                            Label("Safari 打开", systemImage: "safari")
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }

                    Button(action: { Task { await checkPaid() } }) {
                        HStack {
                            if isPolling {
                                ProgressView().tint(.white)
                                Text(pollMessage.isEmpty ? "正在查询支付结果..." : pollMessage)
                                    .font(.system(size: 15, weight: .semibold))
                            } else {
                                Text("我已完成支付")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(LinearGradient(colors: [Color(red: 0.23, green: 0.72, blue: 0.45),
                                                            Color(red: 0.16, green: 0.58, blue: 0.38)],
                                                   startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isPolling)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.09, green: 0.13, blue: 0.22))
            }
            .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
            .navigationTitle("收银台")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") { onFinished(false) })
            .overlay(toastView)
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var toastView: some View {
        if let msg = toast {
            VStack {
                Spacer()
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                Spacer().frame(height: 120)
            }
        }
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == msg { toast = nil }
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = payUrl
        showToast("支付链接已复制，可粘贴到浏览器打开")
    }

    private func openInSafari() {
        if let url = URL(string: payUrl) {
            openURL(url)
        }
    }

    /// 轮询订单支付状态（web 端 recharge/query 同款，最多 15 次 × 3 秒）
    private func checkPaid() async {
        isPolling = true
        pollMessage = ""
        defer { isPolling = false }

        for i in 0..<15 {
            pollMessage = "正在查询支付结果(\(i + 1)/15)..."
            do {
                let paid = try await API.queryOrderPaid(orderNo: orderNo, userEmail: store.email)
                if paid {
                    onFinished(true)
                    return
                }
            } catch {
                // 单次查询失败不中断轮询
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        showToast("未查询到支付结果。如已支付，VIP 将在几分钟内自动生效，可稍后在「会员充值」页查看")
    }
}

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
