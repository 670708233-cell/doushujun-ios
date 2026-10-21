import SwiftUI  // UI 框架：View/UIApplication/Bundle

/// 启动更新检查（对齐安卓 AppUpdater：延迟 2.5s、force_update 不可关闭；iOS 展示提示+跳转链接）：
/// App 启动后后台静默请求版本接口，发现新版本且携带更新日志时弹出更新窗；
/// 强更（force_update=true）无「稍后再说」且点更新后弹窗不关闭。
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()                        // 全局单例（挂到根视图）
    @Published var info: UpdateInfo?                        // 当前待展示的更新信息（nil=不弹窗）

    /// 更新信息载体：版本名/更新日志/是否强更/跳转链接
    struct UpdateInfo {
        let versionName: String  // 展示用版本名（如 2.1.0）
        let log: String          // 更新日志正文（多行）
        let force: Bool          // 是否强制更新（true 隐藏稍后再说）
        let url: String          // 下载/说明页链接
    }

    /// 启动时调用：延迟 2.5 秒后检查（避开启动高峰，不卡首屏）
    func checkOnLaunch() {
        Task {  // 后台并发任务
            try? await Task.sleep(nanoseconds: 2_500_000_000)  // 睡 2.5s（纳秒），出错忽略
            // 带 platform=ios：后端按平台读 ios_app_update_* 配置（不传=安卓键，老安卓包兼容）
            guard let d = try? await Network.get("app/check-update", query: ["platform": "ios"]) else { return }  // 请求失败静默跳过
            // iOS 端无安卓 APK，仅当后端下发了 ios/通用提示时展示（无版本强比对的 URL 载体时忽略）
            guard let log = d["update_log"].str, !log.isEmpty else { return }  // 无更新日志：视为无更新
            let vc = d["version_code"].int ?? 0           // 远端版本号（数字比对基准）
            let local = Bundle.main.infoDictionary?["CFBundleVersion"] as? String  // 本地 build 号字符串
            let localV = Int(local ?? "1") ?? 1           // 本地 build 号（解析失败按 1）
            guard vc > localV else { return }             // 远端不大于本地：无需更新
            await MainActor.run {                         // 切主线程更新 @Published（驱动弹窗）
                info = UpdateInfo(
                    versionName: d["version_name"].str ?? "\(vc)",  // 版本名缺省回退版本号
                    log: log,                                        // 更新日志
                    force: d["force_update"].bool,                   // 强更标记
                    url: d["download_url"].str ?? ""                 // 跳转链接（缺省空）
                )
            }
        }
    }

    /// 打开下载/说明链接（Safari）
    func openUrl(_ s: String) {
        guard let u = URL(string: s), UIApplication.shared.canOpenURL(u) else { return }  // 无效链接静默
        UIApplication.shared.open(u)  // 跳系统浏览器
    }
}

/// 更新弹窗视图：挂在根视图最上层，info 非 nil 时显示半透明遮罩+卡片
struct UpdateSheet: View {
    @ObservedObject var up = AppUpdater.shared  // 观察单例（info 变化即刷新）

    var body: some View {
        Group {
            if let i = up.info {  // 有更新信息才渲染弹窗
                ZStack {  // 遮罩 + 居中卡片
                    Color.black.opacity(0.6).ignoresSafeArea()  // 全屏半透明黑遮罩
                    VStack(spacing: 14) {  // 卡片内容纵向排布
                        Image(systemName: "arrow.up.circle.fill")          // 顶部更新图标
                            .font(.system(size: 40)).foregroundColor(T.primary)
                        Text("发现新版本 v\(i.versionName)")                // 标题：版本名
                            .font(.system(size: 17, weight: .bold)).foregroundColor(T.textMain)
                        ScrollView {                                       // 日志区（超长可滚动）
                            Text(i.log)
                                .font(.system(size: 13)).foregroundColor(T.textSub)
                                .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
                        }
                        .frame(maxHeight: 180)                             // 日志区限高
                        PrimaryButton(title: "立即更新") {                  // 主按钮：跳转更新
                            up.openUrl(i.url)                              // 打开链接
                            if !i.force { up.info = nil }                  // 非强更才关弹窗（强更保持）
                        }
                        if !i.force {                                      // 仅非强更显「稍后再说」
                            Button("稍后再说") { up.info = nil }            // 关闭弹窗
                                .font(.system(size: 13)).foregroundColor(T.textSub)
                        }
                    }
                    .padding(20)                                                       // 卡片内边距
                    .background(RoundedRectangle(cornerRadius: 18).fill(T.card))       // 卡片底色圆角
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(T.stroke, lineWidth: 1))  // 描边
                    .padding(.horizontal, 36)                                          // 卡片左右留白
                }
            }
        }
    }
}
