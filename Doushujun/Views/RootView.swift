import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: UserStore

    var body: some View {
        Group {
            if store.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}
