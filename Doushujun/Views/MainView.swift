import SwiftUI

struct MainView: View {
    @EnvironmentObject private var store: UserStore

    var body: some View {
        TabView {
            WeightQueryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("查权重")
                }
            TiktokQueryView()
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("查作品")
                }
            VipRechargeView()
                .tabItem {
                    Image(systemName: "crown.fill")
                    Text("会员充值")
                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
        }
        .tint(Color(red: 0.4, green: 0.55, blue: 1.0))
        .task {
            async let _ = store.refreshBalance()
            async let _ = store.refreshVip()
        }
    }
}
