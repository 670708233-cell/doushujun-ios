import SwiftUI

@main
struct DoushujunApp: App {
    @ObservedObject private var bus = SessionBus.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bus)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 根容器：登录/主页切换 + 全局 Toast/Loading/更新弹窗

struct RootView: View {
    @ObservedObject private var bus = SessionBus.shared

    var body: some View {
        ZStack {
            if bus.loggedIn {
                MainTabs()
            } else {
                AuthView(onLoginSuccess: {
                    bus.refreshAccount()
                })
            }
        }
        .background(T.bg.ignoresSafeArea())
        .overlay(ToastHost())
        .overlay(BusyOverlay())
        .overlay(UpdateSheet())
        .onAppear {
            if bus.loggedIn { bus.refreshAccount() }
            AppUpdater.shared.checkOnLaunch()
        }
    }
}

/// 全屏 loading 遮罩（bus.busyText 非 nil 时展示）
struct BusyOverlay: View {
    @ObservedObject var bus = SessionBus.shared

    var body: some View {
        if let t = bus.busyText {
            FullLoading(text: t)
        }
    }
}

// MARK: - 主页五 Tab（权重 / 作品 / 监控 / 素材 / 我的）

struct MainTabs: View {
    @ObservedObject private var bus = SessionBus.shared
    @State private var tab = 0

    private enum SheetKind: String, Identifiable {
        case weightHistory, workHistory, vip, invite, feedback
        var id: String { rawValue }
    }
    @State private var sheet: SheetKind? = nil

    var body: some View {
        TabView(selection: $tab) {
            WeightView(onOpenHistory: { sheet = .weightHistory })
                .tabItem { Label("权重", systemImage: "scalemass.fill") }
                .tag(0)
            WorkView(onOpenHistory: { sheet = .workHistory })
                .tabItem { Label("作品", systemImage: "doc.text.magnifyingglass") }
                .tag(1)
            MonitorView()
                .tabItem { Label("监控", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            MaterialView()
                .tabItem { Label("取素材", systemImage: "arrow.down.doc.fill") }
                .tag(3)
            MineView(
                onOpenVip: { sheet = .vip },
                onOpenInvite: { sheet = .invite },
                onOpenFeedback: { sheet = .feedback },
                onLoggedOut: { tab = 0 }
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
        .fullScreenCover(item: $sheet) { kind in
            switch kind {
            case .weightHistory:
                WeightHistoryView(
                    onBack: { sheet = nil },
                    onQuery: { id in
                        sheet = nil
                        bus.pendingWeightId = id
                    }
                )
            case .workHistory:
                WorkHistoryView(
                    onBack: { sheet = nil },
                    onQuery: { vid in
                        sheet = nil
                        bus.pendingWorkId = vid
                    }
                )
            case .vip:
                VipView(onClose: { sheet = nil })
            case .invite:
                InviteView(onClose: { sheet = nil })
            case .feedback:
                FeedbackView(onClose: { sheet = nil })
            }
        }
    }
}
