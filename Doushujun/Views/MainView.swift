import SwiftUI

// ============================================================================
// MainView —— 主界面（四 Tab：查权重 / 查作品 / 会员充值 / 我的）
// 登录成功后由 RootView 切换进入；进入时并行刷新余额与 VIP 状态
// ============================================================================

struct MainView: View {

    @EnvironmentObject private var store: UserStore   // 全局用户状态

    var body: some View {
        TabView {
            // ---- Tab 1：查权重 ----
            WeightQueryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")           // 柱状图图标
                    Text("查权重")
                }
            // ---- Tab 2：查作品 ----
            TiktokQueryView()
                .tabItem {
                    Image(systemName: "video.fill")               // 视频图标
                    Text("查作品")
                }
            // ---- Tab 3：会员充值 ----
            VipRechargeView()
                .tabItem {
                    Image(systemName: "crown.fill")               // 皇冠图标
                    Text("会员充值")
                }
            // ---- Tab 4：我的 ----
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")              // 人像图标
                    Text("我的")
                }
        }
        .tint(Theme.cyan)                                          // 选中态电光青
        .toolbarBackground(Theme.bgSoft, for: .tabBar)             // Tab 栏深空底色
        .toolbarBackground(.visible, for: .tabBar)                 // 强制显示（不透明）
        // 进入主界面：并行拉余额 + VIP（不阻塞 UI）
        .task {
            async let _ = store.refreshBalance()
            async let _ = store.refreshVip()
        }
    }
}
