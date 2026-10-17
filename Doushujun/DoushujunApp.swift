import SwiftUI

@main
struct DoushujunApp: App {
    @StateObject private var store = UserStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
