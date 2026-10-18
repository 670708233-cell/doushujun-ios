import SwiftUI

// ============================================================================
// RootView —— 根视图：登录态切换器
// 已登录 → 主界面（四 Tab）；未登录 → 登录页
// 登录状态由 UserStore 持久化（本地存储 token）
// ============================================================================

struct RootView: View {

    @EnvironmentObject private var store: UserStore   // 全局用户状态（token/用户名/余额/VIP）

    var body: some View {
        if store.isLoggedIn {                          // 有有效登录态
            MainView()                                 // → 主界面
        } else {
            LoginView()                                // → 登录页（App 首屏）
        }
    }
}
