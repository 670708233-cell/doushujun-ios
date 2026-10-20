import Foundation
import SwiftUI

/// 全局状态总线（对齐安卓 SessionBus + VipStore）
/// 余额/点数跨页同步、401 踢登录、跨 Tab 直通车参数、公告
final class SessionBus: ObservableObject {
    static let shared = SessionBus()

    /// 根视图状态：false=显示登录页，true=显示主页
    @Published var loggedIn: Bool = SessionStore.isLoggedIn
    /// 全局错误提示（顶部 Toast）
    @Published var toast: String?
    /// 全屏 loading 文案（nil=隐藏）
    @Published var busyText: String?

    // 账号/余额/VIP（refreshAccount 刷新）
    @Published var username: String = SessionStore.username
    @Published var email: String = SessionStore.email
    @Published var balance: Double = SessionStore.balance
    @Published var vipLevel: String = "免费用户"
    @Published var vipExpire: String = ""
    @Published var consumeToday: Int = 0
    @Published var dailyLimit: Int = 0
    @Published var usedToday: Int = 0

    // 公告（announcement/current，超时静默）
    @Published var announcement: (title: String, content: String)? = nil

    // 跨 Tab 直通车：监控列表 → 新建任务（CreateTaskFlow 预填链接）
    @Published var pendingTaskLink: String? = nil
    // 作品历史 → 分析页直查
    @Published var pendingWorkId: String? = nil
    // 权重历史 → 权重页直查
    @Published var pendingWeightId: String? = nil

    func syncLogin(username: String?, email: String?, balance: Double?) {
        self.username = username ?? SessionStore.username
        self.email = email ?? SessionStore.email
        if let b = balance {
            self.balance = b
            SessionStore.setBalance(b)
        }
    }

    /// 各接口响应 data.new_balance 同步（扣费后余额全局刷新）
    func setBalance(_ v: Double?) {
        guard let v = v else { return }
        balance = v
        SessionStore.setBalance(v)
    }

    /// 消耗次数同步（data.consume_today / used_today）
    func setUsage(consume: Int?, used: Int?, limit: Int?) {
        if let c = consume { consumeToday = c }
        if let u = used { usedToday = u }
        if let l = limit { dailyLimit = l }
    }

    func forceLogout() {
        SessionStore.logout()
        DispatchQueue.main.async {
            self.loggedIn = false
            self.toast = "登录已过期，请重新登录"
        }
    }

    func doLogout() {
        SessionStore.logout()
        DispatchQueue.main.async { self.loggedIn = false }
    }

    /// 拉取公告（失败静默）
    func loadAnnouncement() {
        Task {
            let result = await withTaskGroup(of: J?.self) { g -> J? in
                g.addTask { try? await Network.get("announcement/current") }
                g.addTask { _ -> J? in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    return nil
                }
                defer { g.cancelAll() }
                return await g.next() ?? nil
            }
            if let d = result {
                let title = d["title"].str ?? ""
                let content = d["content"].str ?? ""
                if !content.isEmpty {
                    await MainActor.run { self.announcement = (title, content) }
                }
            }
        }
    }

    /// 刷新账号状态（user/profile：余额+VIP+配额；失败静默）
    func refreshAccount() {
        Task {
            guard let data = try? await Network.get("user/profile") else { return }
            await MainActor.run {
                username = data["username"].str ?? username
                email = data["email"].str ?? email
                if let b = data["balance"].dbl {
                    balance = b
                    SessionStore.setBalance(b)
                }
                vipLevel = data["vip_level_name"].str ?? (data["vip_level"].int.flatMap { $0 > 0 ? "VIP\($0)" : nil } ?? "免费用户")
                vipExpire = data["vip_expire_time"].str ?? ""
                consumeToday = data["consume_today"].int ?? consumeToday
                dailyLimit = data["daily_limit"].int ?? dailyLimit
                usedToday = data["used_today"].int ?? usedToday
            }
        }
    }
}
