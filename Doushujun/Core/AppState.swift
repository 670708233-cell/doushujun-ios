import Foundation  // 基础库：Task/JSON
import SwiftUI     // UI 框架：MainActor/@Published

/// 全局状态总线（对齐安卓 SessionBus + VipStore）：
/// 余额/点数跨页同步、401 踢登录、跨 Tab 直通车参数、公告。
/// 根视图与各业务页共同观察此单例，实现一处更新全局刷新。
final class SessionBus: ObservableObject {
    static let shared = SessionBus()  // 全局单例

    /// 根视图状态：false=显示登录页，true=显示主页
    @Published var loggedIn: Bool = SessionStore.isLoggedIn  // 初值取本地持久化登录态
    /// 全局错误提示（顶部 Toast）
    @Published var toast: String?                            // 非 nil 显示 Toast
    /// 全屏 loading 文案（nil=隐藏）
    @Published var busyText: String?                         // 非 nil 显示全屏 loading

    // 账号/余额/VIP（refreshAccount 刷新）
    @Published var username: String = SessionStore.username  // 用户名（初值取本地）
    @Published var email: String = SessionStore.email        // 邮箱
    @Published var balance: Double = SessionStore.balance    // 余额
    @Published var vipLevel: String = "免费用户"              // VIP 等级名
    @Published var vipExpire: String = ""                    // VIP 到期时间
    @Published var consumeToday: Int = 0                     // 今日消耗点数
    @Published var dailyLimit: Int = 0                       // 每日免费额度
    @Published var usedToday: Int = 0                        // 今日已用次数

    // 公告（announcement/current，超时静默）
    @Published var announcement: (title: String, content: String)? = nil  // 非 nil 显示公告栏

    // 跨 Tab 直通车：监控列表 → 新建任务（CreateTaskFlow 预填链接）
    @Published var pendingTaskLink: String? = nil   // 非 nil 时监控页自动弹新建并预填
    // 作品历史 → 分析页直查
    @Published var pendingWorkId: String? = nil     // 非 nil 时作品页自动发起该 ID 查询
    // 权重历史 → 权重页直查
    @Published var pendingWeightId: String? = nil   // 非 nil 时权重页自动发起该 ID 分析

    /// 登录成功后同步账号三件套到总线（nil 字段保留本地旧值）
    func syncLogin(username: String?, email: String?, balance: Double?) {
        self.username = username ?? SessionStore.username  // 用户名：缺省回退本地
        self.email = email ?? SessionStore.email           // 邮箱：缺省回退本地
        if let b = balance {                               // 余额有值才同步：
            self.balance = b                               // 更新总线
            SessionStore.setBalance(b)                     // 同步落盘
        }
    }

    /// 各接口响应 data.new_balance 同步（扣费后余额全局刷新）
    func setBalance(_ v: Double?) {
        guard let v = v else { return }  // 空值忽略
        balance = v                      // 更新总线（驱动 UI）
        SessionStore.setBalance(v)       // 同步落盘
    }

    /// 消耗次数同步（data.consume_today / used_today）
    func setUsage(consume: Int?, used: Int?, limit: Int?) {
        if let c = consume { consumeToday = c }  // 今日消耗有值才更新
        if let u = used { usedToday = u }        // 已用次数有值才更新
        if let l = limit { dailyLimit = l }      // 每日额度有值才更新
    }

    /// 强制登出（401 会话过期）：清本地令牌并切回登录页，带 Toast 提示
    func forceLogout() {
        SessionStore.logout()               // 清持久化令牌
        DispatchQueue.main.async {          // 切主线程改 @Published
            self.loggedIn = false           // 根视图切登录页
            self.toast = "登录已过期，请重新登录"  // 提示原因
        }
    }

    /// 用户主动退出登录：仅切根视图（无 Toast）
    func doLogout() {
        SessionStore.logout()                       // 清令牌
        DispatchQueue.main.async { self.loggedIn = false }  // 主线程切登录页
    }

    /// 拉取公告（失败静默）：请求与 2.5s 超时赛跑，先到者得
    func loadAnnouncement() {
        Task {  // 后台任务
            let result = await withTaskGroup(of: J?.self) { g -> J? in  // 双任务竞速组
                g.addTask { try? await Network.get("announcement/current") }  // 任务1：请求公告
                g.addTask { () -> J? in                                       // 任务2：2.5s 超时哨兵
                    try? await Task.sleep(nanoseconds: 2_500_000_000)         // 睡 2.5s
                    return nil                                                // 超时返回 nil
                }
                defer { g.cancelAll() }           // 拿到首个结果后取消另一个
                return await g.next() ?? nil      // 先完成者的结果
            }
            if let d = result {                               // 请求胜出且成功：
                let title = d["title"].str ?? ""              // 公告标题
                let content = d["content"].str ?? ""          // 公告正文
                if !content.isEmpty {                         // 正文非空才展示
                    await MainActor.run { self.announcement = (title, content) }  // 主线程发布
                }
            }
        }
    }

    /// 刷新账号状态（user/profile：余额+VIP+配额；失败静默）
    func refreshAccount() {
        Task {  // 后台任务
            guard let data = try? await Network.get("user/profile") else { return }  // 失败静默
            await MainActor.run {  // 主线程批量更新
                username = data["username"].str ?? username          // 用户名（缺省保留旧值）
                email = data["email"].str ?? email                   // 邮箱
                if let b = data["balance"].dbl {                     // 余额有值：
                    balance = b                                      // 更新总线
                    SessionStore.setBalance(b)                       // 落盘
                }
                vipLevel = data["vip_level_name"].str ?? (data["vip_level"].int.flatMap { $0 > 0 ? "VIP\($0)" : nil } ?? "免费用户")  // 等级名：后端名 > 数字拼 VIP > 免费用户
                vipExpire = data["vip_expire_time"].str ?? ""        // 到期时间
                consumeToday = data["consume_today"].int ?? consumeToday  // 今日消耗
                dailyLimit = data["daily_limit"].int ?? dailyLimit   // 每日额度
                usedToday = data["used_today"].int ?? usedToday      // 今日已用
            }
        }
    }
}
