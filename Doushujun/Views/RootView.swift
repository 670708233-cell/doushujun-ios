import SwiftUI

/// 登录态切换：未登录 -> 登录页；已登录 -> 主界面
struct RootView: View {
    @EnvironmentObject private var store: UserStore

    var body: some View {
        if store.isLoggedIn {
            MainView()
        } else {
            LoginView()
        }
    }
}
