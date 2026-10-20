import Foundation  // 基础库：UserDefaults/JSON 编解码

/// 本地会话与历史持久化（对齐安卓 SessionStore：UserDefaults 版 DataStore）：
/// 全静态枚举命名空间——token 会话、余额、三类查询历史（权重/素材/作品）
/// 均存 UserDefaults.standard（删除 App 即彻底清除，无 Keychain 残留）。
enum SessionStore {
    private static let d = UserDefaults.standard  // 统一存储实例
    // ---- 存储键名常量（前缀 dsj_ 防冲突） ----
    private static let kToken = "dsj_token"              // 登录令牌（Bearer）
    private static let kUser = "dsj_username"            // 用户名
    private static let kEmail = "dsj_email"              // 邮箱
    private static let kBalance = "dsj_balance"          // 余额（Double）
    private static let kWeightHistory = "dsj_weight_history"    // 权重查询历史键
    private static let kMaterialHistory = "dsj_material_history" // 素材历史键
    private static let kWorkHistory = "dsj_work_history"        // 作品历史键

    // MARK: - 会话（读写登录态）

    static var token: String? { d.string(forKey: kToken) }           // 令牌（未登录 nil）
    static var username: String { d.string(forKey: kUser) ?? "" }    // 用户名（默认空串）
    static var email: String { d.string(forKey: kEmail) ?? "" }      // 邮箱（默认空串）
    static var balance: Double { d.double(forKey: kBalance) }        // 余额（默认 0）

    /// 是否已登录：token 非空即视为已登录
    static var isLoggedIn: Bool { !(d.string(forKey: kToken) ?? "").isEmpty }

    /// 登录成功后一次性写入会话四件套（balance 可选：nil 不覆盖旧值）
    static func saveLogin(token: String, username: String?, email: String?, balance: Double?) {
        d.set(token, forKey: kToken)            // 写令牌
        d.set(username ?? "", forKey: kUser)    // 写用户名（nil 存空串）
        d.set(email ?? "", forKey: kEmail)      // 写邮箱
        if let b = balance { d.set(b, forKey: kBalance) }  // 余额有值才写
        d.synchronize()  // 立即落盘（防闪退丢会话）
    }

    /// 单独更新余额（消费/充值回调后刷新）
    static func setBalance(_ v: Double) {
        d.set(v, forKey: kBalance)  // 覆盖余额
    }

    /// 退出登录：仅清令牌（用户名/邮箱保留供登录页回显）
    static func logout() {
        d.removeObject(forKey: kToken)  // 删令牌
        d.synchronize()                 // 立即落盘
    }

    // MARK: - 查询历史（通用条目编解码）

    /// 查询历史条目：{id, name, ts}——id 去重键、name 展示名、ts 毫秒时间戳
    struct HistoryEntry: Codable, Identifiable {
        var id: String      // 条目唯一 ID（作品 ID/sec_uid 等）
        var name: String    // 列表展示名（描述/账号名）
        var ts: Double      // 记录时间（毫秒）
    }

    /// 从 UserDefaults 读历史数组：数据损坏（解码失败）静默返回空数组
    private static func loadHist(_ key: String) -> [HistoryEntry] {
        guard let data = d.data(forKey: key) else { return [] }  // 无数据→空
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []  // 解码失败→空
    }

    /// 历史数组编码写回 UserDefaults
    private static func saveHist(_ key: String, _ list: [HistoryEntry]) {
        d.set(try? JSONEncoder().encode(list), forKey: key)  // JSON Data 写入
    }

    /// 插入/置顶一条历史（最多保留 50 条，同 id 去重置顶）
    static func pushHistory(_ key: String, id: String, name: String) {
        var list = loadHist(key).filter { $0.id != id }  // 先剔除同 ID 旧条目（去重）
        list.insert(HistoryEntry(id: id, name: name, ts: Date().timeIntervalSince1970 * 1000), at: 0)  // 新条目插到头部（当前毫秒时间戳）
        if list.count > 50 { list = Array(list.prefix(50)) }  // 超上限裁剪到最近 50 条
        saveHist(key, list)  // 写回
    }

    /// 按 ID 删除单条历史
    static func removeHistory(_ key: String, id: String) {
        saveHist(key, loadHist(key).filter { $0.id != id })  // 过滤掉目标后写回
    }

    /// 读全部历史（列表页渲染）
    static func history(_ key: String) -> [HistoryEntry] { loadHist(key) }

    // ---- 三类历史的存储键暴露（调用方按业务取用） ----
    static var weightHistoryKey: String { kWeightHistory }      // 权重历史键
    static var materialHistoryKey: String { kMaterialHistory }  // 素材历史键
    static var workHistoryKey: String { kWorkHistory }          // 作品历史键
}
