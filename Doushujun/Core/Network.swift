import Foundation

/// 统一 API 错误（对齐安卓 ApiException + Api 会话/维护分类）
enum ApiError: LocalizedError {
    case business(String)      // 业务错误：展示后端 msg
    case sessionExpired        // code 401：会话过期，踢回登录
    case maintenance           // HTTP 503：维护中
    case network(String)

    var errorDescription: String? {
        switch self {
        case .business(let m): return m
        case .sessionExpired: return "登录已过期，请重新登录"
        case .maintenance: return "系统维护中，请稍后再试"
        case .network(let m): return m
        }
    }
}

/// 网络层：所有接口集中定义（对齐安卓 ApiService.kt + RetrofitClient）
final class Network {
    /// 生产环境（安卓当前为本地联调地址，iOS 直接用生产）
    static let baseURL = URL(string: "https://doushujun.me/api/")!
    static let secretKey = "your_secret_key_here526fb87088aa9ac0bea25c0117f7e018"

    /// 需要注入 X-Signature/X-Timestamp 的接口路径（与后端约定）
    static let signedPaths: Set<String> = [
        "v2/query/weight", "v2/query/weight/history", "v2/query/weight/delete",
        "v2/query/douyin", "v2/query/refresh", "v2/query/history", "query/delete",
        "v2/query/ai/analyze", "v2/query/ai/analyze_weight", "v2/query/ai/analyze_result",
        "vip/status",
    ]

    static let shared = Network()
    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.httpAdditionalHeaders = ["User-Agent": "Doushujun-iOS/2.0"]
        session = URLSession(configuration: cfg)
    }

    /// 统一请求：body 任意 JSON（嵌套展平参与签名），返回 data 节点 J
    /// - 成功判定：code==200 || code==1（VIP/支付族）
    static func post(_ path: String, body: [String: Any] = [:], query: [String: String] = [:]) async throws -> J {
        try await shared.request("POST", path, body: body, query: query)
    }

    static func get(_ path: String, query: [String: String] = [:]) async throws -> J {
        try await shared.request("GET", path, body: nil, query: query)
    }

    private func request(_ method: String, _ path: String, body: [String: Any]?, query: [String: String]) async throws -> J {
        var url = URL(string: path, relativeTo: Self.baseURL)!
        if !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            comps.queryItems = (comps.queryItems ?? []) + query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = comps.url!
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 签名材料 = 全部 GET+POST 参数（后端 request->param() 全量比对）
        let ts = Int(Date().timeIntervalSince1970)
        if Self.signedPaths.contains(where: { path.hasSuffix($0) }) {
            var sigParams: [String: Any] = body ?? [:]
            for (k, v) in query { sigParams[k] = v }
            req.setValue(String(ts), forHTTPHeaderField: "X-Timestamp")
            req.setValue(Crypto.webSignature(params: sigParams, timestampSec: ts), forHTTPHeaderField: "X-Signature")
        }

        // Bearer 会话
        if let token = SessionStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let b = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: b)
        }

        // 发送
        let data: Data
        let http: HTTPURLResponse
        do {
            let (d, r) = try await session.data(for: req)
            data = d
            http = r as! HTTPURLResponse
        } catch {
            throw ApiError.network("网络连接失败，请检查网络")
        }

        if http.statusCode == 503 { throw ApiError.maintenance }
        guard let root = try? J(data: data) else {
            throw ApiError.network("服务返回异常(\(http.statusCode))")
        }
        let code = root["code"].int ?? -999
        if code == 401 {
            SessionBus.shared.forceLogout()
            throw ApiError.sessionExpired
        }
        let ok = code == 200 || code == 1
        if !ok {
            throw ApiError.business(root["msg"].str ?? root["message"].str ?? "请求失败，请稍后重试")
        }
        return root["data"]
    }
}
