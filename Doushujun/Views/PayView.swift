import SwiftUI
import WebKit

// ============================================================================
// PayView —— 收银台（第三方支付）
// 顶部提示条 + WKWebView 加载 pay_url + 复制链接/Safari 打开 + 支付结果轮询
// ============================================================================

struct PayView: View {

    // MARK: - 参数

    let orderNo: String                        // 订单号（轮询用）
    let payUrl: String                         // 第三方支付跳转链接
    let onFinished: (_ paid: Bool) -> Void     // 结束回调（true=已支付）

    @EnvironmentObject private var store: UserStore   // 全局状态（邮箱）
    @Environment(\.openURL) private var openURL       // Safari 打开链接

    // MARK: - 状态

    @State private var isPolling = false       // 轮询进行中
    @State private var pollMessage = ""        // 轮询进度文案
    @State private var toast: String?          // 轻提示

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ---- 顶部提示条 ----
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkerboard") // 安全图标
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cyan)
                        Text("请在新打开的页面完成支付")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textMain)
                    }
                    Text("支付完成后点击底部「我已完成支付」查询结果")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.bgSoft)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                }

                // ---- 中间 WebView 加载支付链接 ----
                if let url = URL(string: payUrl) {
                    PayWebView(url: url)
                        .frame(maxHeight: .infinity)
                } else {
                    // 链接无效占位
                    VStack(spacing: 10) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 30)).foregroundStyle(Theme.red)
                        Text("支付链接无效")
                            .font(.system(size: 14)).foregroundColor(Theme.textSub)
                    }
                    .frame(maxHeight: .infinity)
                }

                // ---- 底部操作区 ----
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // 复制支付链接
                        Button(action: copyLink) {
                            Label("复制链接", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textMain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.cardStroke, lineWidth: 1))
                        }
                        // Safari 打开（微信支付在 WebView 可能受限，Safari 更稳）
                        Button(action: openInSafari) {
                            Label("Safari 打开", systemImage: "safari")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textMain)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.cardStroke, lineWidth: 1))
                        }
                    }
                    // 「我已完成支付」绿色发光主按钮（轮询中显示进度）
                    Button {
                        Task { await checkPaid() }
                    } label: {
                        HStack(spacing: 8) {
                            if isPolling {
                                ProgressView().tint(.white)
                                Text(pollMessage.isEmpty ? "正在查询支付结果..." : pollMessage)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                Text("我已完成支付")
                            }
                        }
                    }
                    .buttonStyle(GlowButtonStyle(gradient: Theme.mint, height: 50))
                    .disabled(isPolling)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.bgSoft)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("收银台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgSoft, for: .navigationBar)   // 导航栏深色
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)         // 深色配色
            .navigationBarItems(trailing: Button("关闭") { onFinished(false) }) // 关闭按钮
            .overlay(toastView)                                     // 轻提示浮层
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 轻提示

    @ViewBuilder
    private var toastView: some View {
        if let msg = toast {
            VStack {
                Spacer()
                Text(msg)                                            // 提示文字
                    .font(.system(size: 13.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardStroke, lineWidth: 1))
                Spacer().frame(height: 120)
            }
        }
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {      // 1.8s 后消失
            if toast == msg { toast = nil }
        }
    }

    // MARK: - 操作

    /// 复制支付链接到剪贴板
    private func copyLink() {
        UIPasteboard.general.string = payUrl
        showToast("支付链接已复制，可粘贴到浏览器打开")
    }

    /// 用 Safari 打开（微信 H5 支付在 App 内 WebView 可能拉不起微信）
    private func openInSafari() {
        if let url = URL(string: payUrl) {
            openURL(url)
        }
    }

    /// 轮询订单支付状态（web 端 recharge/query 同款：最多 15 次 × 3 秒）
    private func checkPaid() async {
        isPolling = true
        pollMessage = ""
        defer { isPolling = false }

        for i in 0..<15 {                                            // 最多 15 轮
            pollMessage = "查询中(\(i + 1)/15)..."
            do {
                let paid = try await API.queryOrderPaid(orderNo: orderNo, userEmail: store.email)
                if paid {                                            // status==1 已支付
                    onFinished(true)                                 // 结束并刷新 VIP
                    return
                }
            } catch {
                // 单次失败不中断轮询
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)        // 3 秒间隔
        }
        showToast("未查询到支付结果。如已支付，VIP 将在几分钟内自动生效")
    }
}

// MARK: - WebView 封装

/// WKWebView 封装：加载第三方支付跳转页（支持返回手势）
struct PayWebView: UIViewRepresentable {
    let url: URL                                     // 目标支付链接

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()           // 配置
        cfg.websiteDataStore = .default()            // 默认存储（支付页需要 cookie）
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true // 侧滑返回上一页
        web.load(URLRequest(url: url))               // 立即加载
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {} // 静态页面无需更新
}
