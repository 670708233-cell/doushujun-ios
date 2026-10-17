import Foundation
import SwiftUI

/// web 端账号体系状态（JWT 登录态）
@MainActor
final class UserStore: ObservableObject {

    @Published var token: String
    @Published var username: String
    @Published var email: String
    @Published var balance: Double
    @Published var vipStatus: VipStatus?
    @Published var isLoadingVip = false

    private let defaults = UserDefaults.standard
    private let kToken = "dj_token"
    private let kUsername = "dj_username"
    private let kEmail = "dj_email"
    private let kBalance = "dj_balance"

    var isLoggedIn: Bool { !token.isEmpty }

    init() {
        token = defaults.string(forKey: kToken) ?? ""
        username = defaults.string(forKey: kUsername) ?? ""
        email = defaults.string(forKey: kEmail) ?? ""
        balance = defaults.double(forKey: kBalance)
        API.authToken = token.isEmpty ? nil : token
    }

    func applyLogin(data: [String: Any]) {
        token = API.toStr(data["token"])
        username = API.toStr(data["username"], fallback: API.toStr(data["user_name"]))
        email = API.toStr(data["email"], fallback: API.toStr(data["user_email"]))
        if let b = API.toDouble(data["balance"]) { balance = b }
        persist()
    }

    func logout() {
        token = ""
        username = ""
        email = ""
        balance = 0
        vipStatus = nil
        persist()
    }

    private func persist() {
        API.authToken = token.isEmpty ? nil : token
        defaults.set(token, forKey: kToken)
        defaults.set(username, forKey: kUsername)
        defaults.set(email, forKey: kEmail)
        defaults.set(balance, forKey: kBalance)
    }

    /// 刷新余额（/user/balance）
    @discardableResult
    func refreshBalance() async -> Bool {
        do {
            let d = try await API.fetchBalance()
            if let b = API.toDouble(d["balance"]) { balance = b }
            if !d["username"].isNilOrEmptyString { username = API.toStr(d["username"]) }
            if !d["email"].isNilOrEmptyString { email = API.toStr(d["email"]) }
            persist()
            return true
        } catch {
            return false
        }
    }

    /// 刷新 VIP 状态（/vip/status）
    @discardableResult
    func refreshVip(showLoading: Bool = false) async -> Bool {
        if showLoading { isLoadingVip = true }
        defer { isLoadingVip = false }
        do {
            vipStatus = try await API.fetchVipStatus()
            return true
        } catch {
            return false
        }
    }
}

private extension Optional where Wrapped == Any {
    var isNilOrEmptyString: Bool {
        switch self {
        case nil, .some(NSNull()): return true
        case .some(let v as String): return v.isEmpty
        default: return false
        }
    }
}
