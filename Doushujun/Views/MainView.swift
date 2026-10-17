import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            NavigationView {
                HomeView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Image(systemName: "crown.fill")
                Text("会员中心")
            }
            RechargeView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("购买会员")
                }
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
        }
        .tint(Color(red: 0.4, green: 0.55, blue: 1.0))
    }
}
