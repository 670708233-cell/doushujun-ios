import SwiftUI

/// 启动更新检查（对齐安卓 AppUpdater：延迟 2.5s、force_update 不可关闭；iOS 展示提示+跳转链接）
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()
    @Published var info: UpdateInfo?

    struct UpdateInfo {
        let versionName: String
        let log: String
        let force: Bool
        let url: String
    }

    func checkOnLaunch() {
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let d = try? await Network.get("app/check-update") else { return }
            // iOS 端无安卓 APK，仅当后端下发了 ios/通用提示时展示（无版本强比对的 URL 载体时忽略）
            guard let log = d["update_log"].str, !log.isEmpty else { return }
            let vc = d["version_code"].int ?? 0
            let local = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            let localV = Int(local ?? "1") ?? 1
            guard vc > localV else { return }
            await MainActor.run {
                info = UpdateInfo(
                    versionName: d["version_name"].str ?? "\(vc)",
                    log: log,
                    force: d["force_update"].bool,
                    url: d["download_url"].str ?? ""
                )
            }
        }
    }

    /// 打开下载/说明链接
    func openUrl(_ s: String) {
        guard let u = URL(string: s), UIApplication.shared.canOpenURL(u) else { return }
        UIApplication.shared.open(u)
    }
}

struct UpdateSheet: View {
    @ObservedObject var up = AppUpdater.shared

    var body: some View {
        Group {
            if let i = up.info {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 40)).foregroundColor(T.primary)
                        Text("发现新版本 v\(i.versionName)")
                            .font(.system(size: 17, weight: .bold)).foregroundColor(T.textMain)
                        ScrollView {
                            Text(i.log)
                                .font(.system(size: 13)).foregroundColor(T.textSub)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                        PrimaryButton(title: "立即更新") {
                            up.openUrl(i.url)
                            if !i.force { up.info = nil }
                        }
                        if !i.force {
                            Button("稍后再说") { up.info = nil }
                                .font(.system(size: 13)).foregroundColor(T.textSub)
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(T.stroke, lineWidth: 1))
                    .padding(.horizontal, 36)
                }
            }
        }
    }
}
