import Foundation  // 基础库：URLSession/URLRequest

/// 统一 API 错误（对齐安卓 ApiException + Api 会话/维护分类）：
/// 业务错误直接展示后端 msg；会话过期/维护中由 UI 层特殊处理。
enum ApiError: LocalizedError {
    case business(String)      // 业务错误：展示后端 msg
    case sessionExpired        // code 401：会话过期，踢回登录
    case maintenance           // HTTP 503：维护中
    case notFound              // HTTP 404：接口不存在（如生产后端未部署极验）
    case network(String)

    /// UI 展示文案（LocalizedName 兜底错误弹窗直接显示）
    var errorDescription: String? {
        switch self {
        case .business(let m): return m                    // 业务错误：后端文案
        case .sessionExpired: return "登录已过期，请重新登录"  // 过期固定文案
        case .maintenance: return "系统维护中，请稍后再试"     // 维护固定文案
        case .notFound: return "接口不存在(404)"             // 404 固定文案
        case .network(let m): return m                     // 网络错误：透传
        }
    }
}

/// 网络层：所有接口集中定义（对齐安卓 ApiService.kt + RetrofitClient）：
/// 统一 URL 拼接（base=/api/）、签名头（X-Signature/X-Timestamp）、
/// Bearer 会话头、JSON 编解码、错误分类。调用方只关心路径与参数。
final class Network {
    /// 生产环境（安卓当前为本地联调地址，iOS 直接用生产）
    static let baseURL = URL(string: "https://doushujun.me/api/")!  // 带 / 结尾保证相对路径正确追加
    static let secretKey = "your_secret_key_here526fb87088aa9ac0bea25c0117f7e018"  // 签名密钥（与 web 端一致）

    /// 需要注入 X-Signature/X-Timestamp 的接口路径（与后端约定）
    static let signedPaths: Set<String> = [        // 后缀匹配：覆盖 v2 全族+VIP
        "v2/query/weight", "v2/query/weight/history", "v2/query/weight/delete",
        "v2/query/douyin", "v2/query/refresh", "v2/query/history", "query/delete",
        "v2/query/ai/analyze", "v2/query/ai/analyze_weight", "v2/query/ai/analyze_result",
        "vip/status",
    ]

    static let shared = Network()  // 单例（持 URLSession）
    private let session: URLSession  // 会话实例（带默认头）

    /// 私有构造：配置 30s 超时 + 统一 User-Agent
    private init() {
        let cfg = URLSessionConfiguration.default       // 默认配置
        cfg.timeoutIntervalForRequest = 30              // 请求超时 30 秒
        cfg.httpAdditionalHeaders = ["User-Agent": "Doushujun-iOS/2.0"]  // 后端识别客户端
        session = URLSession(configuration: cfg)        // 构建会话
    }

    /// 统一请求：body 任意 JSON（嵌套展平参与签名），返回 data 节点 J
    /// - 成功判定：code==200 || code==1（VIP/支付族）
    static func post(_ path: String, body: [String: Any] = [:], query: [String: String] = [:]) async throws -> J {
        try await shared.request("POST", path, body: body, query: query)  // POST 转发
    }

    /// GET 请求：仅 query 参数
    static func get(_ path: String, query: [String: String] = [:]) async throws -> J {
        try await shared.request("GET", path, body: nil, query: query)    // GET 转发
    }

    /// 核心请求实现：拼 URL → 注签名/会话头 → 发送 → 错误分类 → 取 data 节点
    private func request(_ method: String, _ path: String, body: [String: Any]?, query: [String: String]) async throws -> J {
        var url = URL(string: path, relativeTo: Self.baseURL)!  // 相对路径拼 base（base 带 / 尾保证追加语义）
        if !query.isEmpty {                                     // 有 query 参数：
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: true)!  // 组件化
            comps.queryItems = (comps.queryItems ?? []) + query.map { URLQueryItem(name: $0.key, value: $0.value) }  // 追加查询项
            url = comps.url!                                    // 回写 URL
        }
        var req = URLRequest(url: url)                          // 构建请求
        req.httpMethod = method                                 // 方法
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")  // JSON 体

        // 签名材料 = 全部 GET+POST 参数（后端 request->param() 全量比对）
        let ts = Int(Date().timeIntervalSince1970)              // 当前秒级时间戳
        if Self.signedPaths.contains(where: { path.hasSuffix($0) }) {  // 命中签名接口清单（后缀匹配）：
            var sigParams: [String: Any] = body ?? [:]          // 签名参数基体：POST body
            for (k, v) in query { sigParams[k] = v }            // 合并 query 参数
            req.setValue(String(ts), forHTTPHeaderField: "X-Timestamp")                       // 时间戳头
            req.setValue(Crypto.webSignature(params: sigParams, timestampSec: ts), forHTTPHeaderField: "X-Signature")  // SHA-256 签名头
        }

        // Bearer 会话
        if let token = SessionStore.token {                     // 本地有令牌：
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")  // 注会话头
        }

        if let b = body {                                       // 有 body：
            req.httpBody = try JSONSerialization.data(withJSONObject: b)  // JSON 序列化
        }

        // 发送
        let data: Data                                          // 响应体
        let http: HTTPURLResponse                               // 响应头
        do {
            let (d, r) = try await session.data(for: req)       // 异步发送
            data = d
            http = r as! HTTPURLResponse                        // 强转 HTTP 响应
        } catch {                                               // 传输层失败：
            throw ApiError.network("网络连接失败，请检查网络")     // 统一网络错误文案
        }

        if http.statusCode == 503 { throw ApiError.maintenance }  // 维护中：专用错误
        if http.statusCode == 404 { throw ApiError.notFound }     // 接口不存在：专用错误（供降级判断）
        guard let root = try? J(data: data) else {                // 响应非合法 JSON：
            throw ApiError.network("服务返回异常(\(http.statusCode))")  // 带 HTTP 码的网络错误
        }
        let code = root["code"].int ?? -999                      // 业务码（缺失按失败）
        if code == 401 {                                         // 会话过期：
            SessionBus.shared.forceLogout()                      // 全局踢回登录页
            throw ApiError.sessionExpired                        // 抛过期错误
        }
        let ok = code == 200 || code == 1                        // 成功码：200 或 1（VIP/支付族）
        if !ok {                                                 // 业务失败：
            throw ApiError.business(root["msg"].str ?? root["message"].str ?? "请求失败，请稍后重试")  // 展示后端文案
        }
        return root["data"]                                      // 成功：返回 data 节点
    }
}
