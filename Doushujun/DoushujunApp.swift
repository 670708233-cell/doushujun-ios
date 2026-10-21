import SwiftUI

// ============================================================================
// DoushujunApp.swift — App 入口与根导航容器
// 职责：@main 入口 → RootView（登录/主页切换 + 全局浮层）→ MainTabs（五 Tab）
//       + 全屏弹层路由（历史/VIP/邀请/反馈）
// ============================================================================

/// App 入口：持有 SessionBus 总线，全局强制深色模式
@main
struct DoushujunApp: App {
    @ObservedObject private var bus = SessionBus.shared   // 全局会话总线（登录态/余额/直通车信号）

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bus)                    // 总线下发全树（子视图可 @EnvironmentObject 取）
                .preferredColorScheme(.dark)               // 锁定深色配色（与 T 色板一致）
        }
    }
}

// MARK: - 根容器：登录/主页切换 + 全局 Toast/Loading/更新弹窗

/// 根视图：按登录态二选一切换，并挂载三类全局浮层
struct RootView: View {
    @ObservedObject private var bus = SessionBus.shared

    var body: some View {
        ZStack {
            if bus.loggedIn {                              // 已登录 → 主页五 Tab
                MainTabs()
            } else {                                       // 未登录 → 登录/注册页
                AuthView(onLoginSuccess: {
                    bus.refreshAccount()                   // 登录成功即拉取账户信息（余额/VIP）
                })
            }
        }
        .background(T.bg.ignoresSafeArea())                // 深空底色铺满安全区外
        .overlay(ToastHost())                              // 全局 Toast（顶层）
        .overlay(BusyOverlay())                            // 全屏 loading 遮罩
        .overlay(UpdateSheet())                            // 强更/选更弹窗（AppUpdater 驱动）
        .onAppear {
            if bus.loggedIn { bus.refreshAccount() }       // 冷启动已登录：补拉账户
            AppUpdater.shared.checkOnLaunch()              // 启动延迟检查版本更新
        }
    }
}

/// 全屏 loading 遮罩（bus.busyText 非 nil 时展示）
struct BusyOverlay: View {
    @ObservedObject var bus = SessionBus.shared

    var body: some View {
        if let t = bus.busyText {                          // 有 busy 文案才显示遮罩
            FullLoading(text: t)
        }
    }
}

// MARK: - 主页五 Tab（权重 / 作品 / 监控 / 素材 / 我的）

/// 主 Tab 容器：五页切换 + 跨页直通车信号监听 + 全屏弹层路由
struct MainTabs: View {
    @ObservedObject private var bus = SessionBus.shared
    @State private var tab = 0                             // 当前选中 Tab（默认权重页）

    /// 全屏弹层种类（Identifiable 供 fullScreenCover(item:) 使用）
    private enum SheetKind: String, Identifiable {
        case weightHistory, workHistory, vip, invite, feedback
        var id: String { rawValue }
    }
    @State private var sheet: SheetKind? = nil             // 当前弹层（nil=无）

    var body: some View {
        TabView(selection: $tab) {
            WeightView(onOpenHistory: { sheet = .weightHistory })          // 0 权重查询
                .tabItem { Label("AI账号权重分析", systemImage: "scalemass.fill") }
                .tag(0)
            WorkView(onOpenHistory: { sheet = .workHistory })              // 1 作品解析
                .tabItem { Label("AI作品优化分析", systemImage: "doc.text.magnifyingglass") }
                .tag(1)
            MonitorView()                                                  // 2 数据监控
                .tabItem { Label("作品数据监控走势", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            MaterialView()                                                 // 3 取素材
                .tabItem { Label("取素材", systemImage: "arrow.down.doc.fill") }
                .tag(3)
            MineView(                                                      // 4 我的（含 VIP/邀请/反馈入口）
                onOpenVip: { sheet = .vip },
                onOpenInvite: { sheet = .invite },
                onOpenFeedback: { sheet = .feedback },
                onLoggedOut: { tab = 0 }                   // 退出登录后回到权重页
            )
            .tabItem { Label("我的", systemImage: "person.fill") }
            .tag(4)
        }
        .onChange(of: bus.pendingWorkId) { id in
            // 直通车：权重页封面/作品历史 → 作品分析页
            if id != nil { tab = 1 }
        }
        .onChange(of: bus.pendingWeightId) { id in
            // 直通车：权重历史 → 权重页直查
            if id != nil { tab = 0 }
        }
        .onChange(of: bus.pendingTaskLink) { link in
            // 直通车：权重页封面 → 监控新建任务预填
            if link != nil { tab = 2 }
        }
        .fullScreenCover(item: $sheet) { kind in           // 弹层路由：按种类装配目标页
            switch kind {
            case .weightHistory:                           // 权重历史（可回跳直查）
                WeightHistoryView(
                    onBack: { sheet = nil },
                    onQuery: { id in
                        sheet = nil
                        bus.pendingWeightId = id           // 关弹层并点亮直通车信号
                    }
                )
            case .workHistory:                             // 作品历史（可回跳直查）
                WorkHistoryView(
                    onBack: { sheet = nil },
                    onQuery: { vid in
                        sheet = nil
                        bus.pendingWorkId = vid
                    }
                )
            case .vip:                                     // VIP 中心
                VipView(onClose: { sheet = nil })
            case .invite:                                  // 邀请返利
                InviteView(onClose: { sheet = nil })
            case .feedback:                                // 意见反馈
                FeedbackView(onClose: { sheet = nil })
            }
        }
    }
}
