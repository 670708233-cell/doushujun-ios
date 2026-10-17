import Foundation
import Combine

@MainActor
final class UserStore: ObservableObject {
    static let userIdKey = "doushujun_userid"

    @Published var userId: String
    @Published var vipStatus: VipStatus?
    @Published var isLoadingVip = false

    init() {
        userId = UserDefaults.standard.string(forKey: Self.userIdKey) ?? ""
    }

    var isLoggedIn: Bool { !userId.isEmpty }

    /// 登录：校验用户ID在小程序用户体系中存在（通过 VIP 状态接口验证）
    func login(_ inputId: String) async throws {
        let uid = inputId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else {
            throw APIError.server("请输入用户ID")
        }
        let status = try await API.fetchVipStatus(userId: uid)
        userId = uid
        vipStatus = status
        UserDefaults.standard.set(uid, forKey: Self.userIdKey)
    }

    /// 刷新会员状态
    func refreshVip(showLoading: Bool = false) async -> Bool {
        guard isLoggedIn else { return false }
        if showLoading { isLoadingVip = true }
        defer { if showLoading { isLoadingVip = false } }
        do {
            vipStatus = try await API.fetchVipStatus(userId: userId)
            return true
        } catch {
            return false
        }
    }

    func logout() {
        userId = ""
        vipStatus = nil
        UserDefaults.standard.removeObject(forKey: Self.userIdKey)
    }
}
