import Foundation

/// 本地会话与历史持久化（对齐安卓 SessionStore：UserDefaults 版 DataStore）
enum SessionStore {
    private static let d = UserDefaults.standard
    private static let kToken = "dsj_token"
    private static let kUser = "dsj_username"
    private static let kEmail = "dsj_email"
    private static let kBalance = "dsj_balance"
    private static let kWeightHistory = "dsj_weight_history"
    private static let kMaterialHistory = "dsj_material_history"
    private static let kWorkHistory = "dsj_work_history"

    // MARK: - 会话

    static var token: String? { d.string(forKey: kToken) }
    static var username: String { d.string(forKey: kUser) ?? "" }
    static var email: String { d.string(forKey: kEmail) ?? "" }
    static var balance: Double { d.double(forKey: kBalance) }

    static var isLoggedIn: Bool { !(d.string(forKey: kToken) ?? "").isEmpty }

    static func saveLogin(token: String, username: String?, email: String?, balance: Double?) {
        d.set(token, forKey: kToken)
        d.set(username ?? "", forKey: kUser)
        d.set(email ?? "", forKey: kEmail)
        if let b = balance { d.set(b, forKey: kBalance) }
        d.synchronize()
    }

    static func setBalance(_ v: Double) {
        d.set(v, forKey: kBalance)
    }

    static func logout() {
        d.removeObject(forKey: kToken)
        d.synchronize()
    }

    // MARK: - 查询历史（通用条目编解码）

    /// 查询历史条目：{id, name, ts}
    struct HistoryEntry: Codable, Identifiable {
        var id: String
        var name: String
        var ts: Double
    }

    private static func loadHist(_ key: String) -> [HistoryEntry] {
        guard let data = d.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    private static func saveHist(_ key: String, _ list: [HistoryEntry]) {
        d.set(try? JSONEncoder().encode(list), forKey: key)
    }

    /// 插入/置顶一条历史（最多保留 50 条，同 id 去重置顶）
    static func pushHistory(_ key: String, id: String, name: String) {
        var list = loadHist(key).filter { $0.id != id }
        list.insert(HistoryEntry(id: id, name: name, ts: Date().timeIntervalSince1970 * 1000), at: 0)
        if list.count > 50 { list = Array(list.prefix(50)) }
        saveHist(key, list)
    }

    static func removeHistory(_ key: String, id: String) {
        saveHist(key, loadHist(key).filter { $0.id != id })
    }

    static func history(_ key: String) -> [HistoryEntry] { loadHist(key) }

    static var weightHistoryKey: String { kWeightHistory }
    static var materialHistoryKey: String { kMaterialHistory }
    static var workHistoryKey: String { kWorkHistory }
}
