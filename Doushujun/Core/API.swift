import Foundation

// MARK: - 数据模型（手动解析，兼容后端字段的类型不确定）

struct VipPackage: Identifiable, Hashable {
    let id: Int
    let name: String
    let price: String
    let duration: Int
    let dailyLimit: Int
    let type: Int   // 1=低请求版 2=高请求版
    let sortOrder: Int

    var durationText: String {
        duration == 0 ? "永久会员" : "\(duration)天"
    }

    static func from(_ dict: [String: Any]) -> VipPackage? {
        guard let id = API.toInt(dict["id"]) else { return nil }
        return VipPackage(
            id: id,
            name: API.toStr(dict["name"], fallback: "套餐"),
            price: API.toPriceText(dict["price"]),
            duration: API.toInt(dict["duration"]) ?? 0,
            dailyLimit: API.toInt(dict["daily_limit"]) ?? 0,
            type: API.toInt(dict["type"]) ?? 1,
            sortOrder: API.toInt(dict["sort_order"]) ?? 0
        )
    }
}

struct VipStatus {
    var isVip: Bool = false
    var packageName: String = "普通用户"
    var startTime: String = ""
    var endTime: String = ""
    var remainDays: Int = 0

    var isPermanent: Bool { endTime.isEmpty && remainDays == -1 }
    var remainText: String { isPermanent ? "永久" : "\(remainDays)天" }

    static func from(_ dict: [String: Any]) -> VipStatus {
        var s = VipStatus()
        if let b = dict["is_vip"] as? Bool {
            s.isVip = b
        } else if let i = API.toInt(dict["is_vip"]) {
            s.isVip = i == 1
        } else if let n = dict["is_vip"] as? NSNumber {
            s.isVip = n.boolValue
        }
        s.packageName = API.toStr(dict["package_name"], fallback: "普通用户")
        s.startTime = API.toStr(dict["start_time"], fallback: "")
        if let et = dict["end_time"] as? String { s.endTime = et }
        if let rd = API.toInt(dict["remain_days"]) { s.remainDays = rd }
        return s
    }
}

struct CreateOrderResult {
    let orderNo: String
    let payUrl: String
    let qrcodeUrl: String
}

enum APIError: LocalizedError {
    case network(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .network(let m): return m
        case .server(let m): return m
        }
    }
}

// MARK: - API 客户端

enum API {
    /// 与微信小程序「doushujun_wx对接第三方支付」同源后端
    static let baseURL = "https://duochacha.top"

    static func toStr(_ v: Any?, fallback: String = "") -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return fallback
    }

    static func toInt(_ v: Any?) -> Int? {
        if let n = v as? Int { return n }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        if let d = v as? Double { return Int(d) }
        return nil
    }

    static func toPriceText(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber {
            let f = NumberFormatter()
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = 2
            return f.string(from: n) ?? n.stringValue
        }
        return "0"
    }

    /// 统一请求：返回解析后的 JSON 字典
    static func request(path: String,
                        method: String = "GET",
                        body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.network("无效的请求地址")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network("网络请求失败：\(error.localizedDescription)")
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.network("无效的服务器响应")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else {
            throw APIError.server("服务器返回数据异常(HTTP \(http.statusCode))")
        }
        return dict
    }

    // MARK: 1. VIP 套餐列表  GET /api/mini_program/vip/packages

    static func fetchPackages() async throws -> [VipPackage] {
        let dict = try await request(path: "/api/mini_program/vip/packages")
        guard (dict["status"] as? String) == "success",
              let arr = dict["data"] as? [[String: Any]] else {
            throw APIError.server(API.toStr(dict["message"], fallback: "获取套餐失败"))
        }
        return arr.compactMap { VipPackage.from($0) }
    }

    // MARK: 2. 创建订单(第三方支付)  POST /api/mini_program/vip/create-order

    static func createOrder(userId: String,
                            packageId: Int,
                            payType: String) async throws -> CreateOrderResult {
        let dict = try await request(path: "/api/mini_program/vip/create-order",
                                     method: "POST",
                                     body: ["user_id": userId,
                                            "package_id": packageId,
                                            "type": payType,
                                            "device_type": "jump"])
        guard (dict["status"] as? String) == "success",
              let data = dict["data"] as? [String: Any] else {
            throw APIError.server(API.toStr(dict["message"], fallback: "创建订单失败"))
        }
        let orderNo = API.toStr(data["order_no"])
        var payUrl = ""
        var qrcodeUrl = ""
        if let info = data["pay_info"] as? [String: Any] {
            payUrl = API.toStr(info["pay_url"])
            qrcodeUrl = API.toStr(info["qrcode_url"])
        }
        if orderNo.isEmpty {
            throw APIError.server("订单创建异常：缺少订单号")
        }
        return CreateOrderResult(orderNo: orderNo, payUrl: payUrl, qrcodeUrl: qrcodeUrl)
    }

    // MARK: 3. 订单支付结果  GET /api/mini_program/vip/return-url?out_trade_no=

    /// 返回 true 表示已支付
    static func queryOrderPaid(orderNo: String) async throws -> Bool {
        let enc = orderNo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? orderNo
        let dict = try await request(path: "/api/mini_program/vip/return-url?out_trade_no=\(enc)")
        guard (dict["status"] as? String) == "success",
              let data = dict["data"] as? [String: Any] else {
            throw APIError.server(API.toStr(dict["message"], fallback: "查询订单失败"))
        }
        return API.toStr(data["status"]) == "paid"
    }

    // MARK: 4. 用户 VIP 状态  POST /api/mini_program/vip/status

    static func fetchVipStatus(userId: String) async throws -> VipStatus {
        let dict = try await request(path: "/api/mini_program/vip/status",
                                     method: "POST",
                                     body: ["user_id": userId])
        if (dict["status"] as? String) == "error" {
            let msg = API.toStr(dict["message"], fallback: "查询失败")
            throw APIError.server(msg)
        }
        guard let data = dict["data"] as? [String: Any] else {
            throw APIError.server("会员状态数据异常")
        }
        return VipStatus.from(data)
    }
}
