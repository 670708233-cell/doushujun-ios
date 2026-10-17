import Foundation

// MARK: - 数据模型

struct RegisterInfo {
    var allowRegister: Bool
    var newUserBonus: Double
    var allowedEmailDomains: [String]
}

struct VipPackage {
    var id: Int
    var name: String
    var price: String
    var duration: Int
    var type: Int
    var dailyLimit: Int
    var description: String

    var durationText: String {
        if duration >= 365 { return "\(duration / 365) 年" }
        if duration >= 30 { return "\(duration / 30) 个月" }
        return "\(duration) 天"
    }
}

struct VipStatus {
    var isVip: Bool
    var packageName: String
    var startTime: String
    var endTime: String
    var remainDays: Int?

    var remainText: String {
        if isPermanent { return "永久有效" }
        if let d = remainDays { return "剩余 \(d) 天" }
        return endTime
    }
    var isPermanent: Bool {
        endTime.isEmpty || endTime.contains("永久") || endTime.contains("2099")
    }
}

struct OrderResult {
    var orderNo: String
    var payUrl: String
}

// MARK: - API 客户端（web 端同款接口）

enum APIError: LocalizedError {
    case server(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .badResponse: return "服务器响应格式异常"
        }
    }
}

enum API {

    /// web 端同源后端
    static let baseURL = "https://doushujun.me/api"
    /// 与 web 端 utils/signature.js 相同的签名密钥
    static let signSecret = "your_secret_key_here526fb87088aa9ac0bea25c0117f7e018"

    /// 当前 JWT（由 UserStore 注入）
    static var authToken: String?

    // MARK: 基础请求

    @discardableResult
    static func request(_ path: String,
                        method: String = "GET",
                        body: [String: Any]? = nil,
                        auth: Bool = false,
                        signed: Bool = false) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.server("接口地址错误")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("DoushujuniOS/2.0", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any]? = body
        if signed {
            let ts = Int(Date().timeIntervalSince1970)
            let source = payload ?? [:]
            let signature = Crypto.sign(source, secret: signSecret, timestamp: ts)
            req.setValue(String(ts), forHTTPHeaderField: "X-Timestamp")
            req.setValue(signature, forHTTPHeaderField: "X-Signature")
        }
        if auth {
            guard let token = authToken, !token.isEmpty else {
                throw APIError.server("登录已失效，请重新登录")
            }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if method != "GET", let p = payload {
            req.httpBody = try JSONSerialization.data(withJSONObject: p)
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.badResponse
        }
        _ = resp
        return dict
    }

    /// 统一解析 code==expect 的 data，失败抛出 msg
    static func expectData(_ dict: [String: Any], expect: Int = 200) throws -> Any {
        let code = (dict["code"] as? NSNumber)?.intValue
            ?? Int((dict["code"] as? String) ?? "-1") ?? -1
        if code != expect {
            let msg = dict["msg"] as? String ?? dict["message"] as? String ?? "请求失败(\(code))"
            throw APIError.server(msg)
        }
        return dict["data"] ?? NSNull()
    }

    static func toInt(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? Int(Double(s)) }
        return nil
    }

    static func toDouble(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func toStr(_ v: Any?, fallback: String = "") -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if v is NSNull || v == nil { return fallback }
        return String(describing: v)
    }

    // MARK: - 验证码

    struct CaptchaImage {
        var captchaKey: String
        var base64Image: String
    }

    /// GET /captcha/generate -> data{captcha_image(base64), captcha_key}
    static func generateCaptcha() async throws -> CaptchaImage {
        let dict = try await request("/captcha/generate")
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        var img = toStr(d["captcha_image"])
        if img.isEmpty { img = toStr(d["captcha_image_base64"]) }
        return CaptchaImage(captchaKey: toStr(d["captcha_key"]),
                            base64Image: img)
    }

    struct SliderSeed {
        var captchaKey: String
        var aesKey: String
        var aesIv: String
    }

    /// GET /captcha/slider/generate -> data{captcha_key, aes_key, aes_iv}
    static func generateSliderSeed() async throws -> SliderSeed {
        let dict = try await request("/captcha/slider/generate")
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        return SliderSeed(captchaKey: toStr(d["captcha_key"]),
                          aesKey: toStr(d["aes_key"]),
                          aesIv: toStr(d["aes_iv"]))
    }

    /// POST /captcha/slider/verify {captcha_key, payload} -> data{slider_token}
    static func verifySlider(captchaKey: String, aesKey: String, aesIv: String,
                             track: [String: Any]) async throws -> String {
        guard let json = try? JSONSerialization.data(withJSONObject: track),
              let jsonStr = String(data: json, encoding: .utf8),
              let encrypted = Crypto.aesCbcEncryptBase64(plain: jsonStr, key: aesKey, iv: aesIv) else {
            throw APIError.server("滑块数据加密失败")
        }
        let dict = try await request("/captcha/slider/verify", method: "POST",
                                     body: ["captcha_key": captchaKey, "payload": encrypted])
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        let token = toStr(d["slider_token"])
        if token.isEmpty { throw APIError.server("滑块验证失败") }
        return token
    }

    // MARK: - 登录 / 注册 / 找回密码

    /// POST /user/login
    static func login(username: String, password: String,
                      captchaKey: String, captchaCode: String,
                      sliderToken: String) async throws -> [String: Any] {
        let dict = try await request("/user/login", method: "POST", body: [
            "username": username,
            "password": password,
            "captcha_key": captchaKey,
            "captcha_code": captchaCode,
            "slider_token": sliderToken,
        ])
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        return d
    }

    /// GET /admin/getregisterInfo
    static func fetchRegisterInfo() async throws -> RegisterInfo {
        let dict = try await request("/admin/getregisterInfo")
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        let allow = (d["allow_register"] as? Bool) ?? ((toInt(d["allow_register"]) ?? 1) == 1)
        let domains: [String]
        if let arr = d["allowed_email_domains"] as? [Any] {
            domains = arr.map { toStr($0) }
        } else if let s = d["allowed_email_domains"] as? String, !s.isEmpty {
            domains = s.split(separator: ",").map(String.init)
        } else {
            domains = []
        }
        return RegisterInfo(allowRegister: allow,
                            newUserBonus: toDouble(d["new_user_bonus"]) ?? 0,
                            allowedEmailDomains: domains)
    }

    /// POST /user/check-username
    static func checkUsername(_ username: String) async throws -> Bool {
        let dict = try await request("/user/check-username", method: "POST",
                                     body: ["username": username])
        let data = try expectData(dict)
        if let d = data as? [String: Any] {
            return (d["available"] as? Bool) ?? ((toInt(d["available"]) ?? 1) == 1)
        }
        return true
    }

    /// POST /user/check-email
    static func checkEmail(_ email: String) async throws -> Bool {
        let dict = try await request("/user/check-email", method: "POST",
                                     body: ["email": email])
        let data = try expectData(dict)
        if let d = data as? [String: Any] {
            return (d["available"] as? Bool) ?? ((toInt(d["available"]) ?? 1) == 1)
        }
        return true
    }

    /// POST /user/sendcode
    static func sendEmailCode(userEmail: String, captchaKey: String, captchaCode: String) async throws {
        let dict = try await request("/user/sendcode", method: "POST", body: [
            "user_email": userEmail,
            "captcha_key": captchaKey,
            "captcha_code": captchaCode,
        ])
        _ = try expectData(dict)
    }

    /// POST /user/register
    static func register(username: String, email: String, password: String,
                         emailCode: String, captchaKey: String, captchaCode: String) async throws {
        let dict = try await request("/user/register", method: "POST", body: [
            "username": username,
            "email": email,
            "password": password,
            "email_code": emailCode,
            "captcha_key": captchaKey,
            "captcha_code": captchaCode,
        ])
        _ = try expectData(dict)
    }

    /// POST /reset_password/checkEmailForReset
    static func checkEmailForReset(_ email: String) async throws {
        let dict = try await request("/reset_password/checkEmailForReset", method: "POST",
                                     body: ["email": email])
        _ = try expectData(dict)
    }

    /// POST /reset_password/sendResetCode
    static func sendResetCode(_ email: String) async throws {
        let dict = try await request("/reset_password/sendResetCode", method: "POST",
                                     body: ["email": email])
        _ = try expectData(dict)
    }

    /// POST /reset_password/resetPassword
    static func resetPassword(email: String, emailCode: String, newPassword: String) async throws {
        let dict = try await request("/reset_password/resetPassword", method: "POST", body: [
            "email": email,
            "email_code": emailCode,
            "new_password": newPassword,
        ])
        _ = try expectData(dict)
    }

    // MARK: - 用户信息

    /// POST /user/balance -> data{user_id, balance, username, email, ...}
    static func fetchBalance() async throws -> [String: Any] {
        let dict = try await request("/user/balance", method: "POST", body: [:], auth: true)
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        return d
    }

    /// POST /user/change_password
    static func changePassword(oldPassword: String, newPassword: String) async throws {
        let dict = try await request("/user/change_password", method: "POST", body: [
            "old_password": oldPassword,
            "new_password": newPassword,
            "confirm_password": newPassword,
        ], auth: true)
        _ = try expectData(dict)
    }

    // MARK: - VIP / 支付（web 端同款）

    /// GET /vip/status
    static func fetchVipStatus() async throws -> VipStatus {
        let dict = try await request("/vip/status", auth: true)
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        var s = VipStatus(isVip: false, packageName: "普通用户", startTime: "", endTime: "", remainDays: nil)
        if let b = d["is_vip"] as? Bool {
            s.isVip = b
        } else if let i = toInt(d["is_vip"]) {
            s.isVip = i == 1
        } else if let n = d["is_vip"] as? NSNumber {
            s.isVip = n.boolValue
        }
        s.packageName = toStr(d["package_name"], fallback: s.isVip ? "VIP会员" : "普通用户")
        s.startTime = toStr(d["start_time"])
        if let et = d["end_time"] as? String { s.endTime = et }
        if let rd = toInt(d["remain_days"]) { s.remainDays = rd }
        return s
    }

    /// GET /vip/packages
    static func fetchPackages() async throws -> [VipPackage] {
        let dict = try await request("/vip/packages")
        let data = try expectData(dict)
        guard let arr = data as? [Any] else { return [] }
        var list: [VipPackage] = []
        for item in arr {
            guard let d = item as? [String: Any] else { continue }
            var p = VipPackage(id: toInt(d["id"]) ?? 0,
                               name: toStr(d["name"]),
                               price: toPriceText(d["price"]),
                               duration: toInt(d["duration"]) ?? 30,
                               type: toInt(d["type"]) ?? 1,
                               dailyLimit: toInt(d["daily_limit"]) ?? 300,
                               description: toStr(d["description"]))
            if p.name.isEmpty { p.name = "VIP 套餐" }
            list.append(p)
        }
        return list
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

    /// POST /vip/create-order {package_id, type, user_email, device_type}
    static func createOrder(packageId: Int, payType: String, userEmail: String) async throws -> OrderResult {
        let dict = try await request("/vip/create-order", method: "POST", body: [
            "package_id": packageId,
            "type": payType,
            "user_email": userEmail,
            "device_type": "desktop",
        ], auth: true)
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        var orderNo = toStr(d["out_trade_no"])
        if orderNo.isEmpty { orderNo = toStr(d["order_no"]) }
        if orderNo.isEmpty { orderNo = toStr(d["order_sn"]) }
        let payUrl = toStr(d["pay_url"])
        return OrderResult(orderNo: orderNo, payUrl: payUrl)
    }

    /// POST /recharge/query {out_trade_no, user_email} -> data.status == 1 已支付
    static func queryOrderPaid(orderNo: String, userEmail: String) async throws -> Bool {
        let dict = try await request("/recharge/query", method: "POST", body: [
            "out_trade_no": orderNo,
            "user_email": userEmail,
        ], auth: true)
        // web 端 recharge/query 成功码为 1
        let data = try expectData(dict, expect: 1)
        guard let d = data as? [String: Any] else { return false }
        if let status = toInt(d["status"]) { return status == 1 }
        if let s = d["status"] as? String { return s == "1" || s.lowercased() == "paid" }
        return false
    }

    // MARK: - 查询（需登录 + 签名）

    /// POST /v2/query/weight {user_email, input}
    /// 响应 data{weight_info{...}, new_balance, remaining_queries, is_vip}
    static func queryWeight(userEmail: String, input: String) async throws -> [String: Any] {
        let dict = try await request("/v2/query/weight", method: "POST", body: [
            "user_email": userEmail,
            "input": input,
        ], auth: true, signed: true)
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        return d
    }

    /// POST /v2/query/getvideosinfo {user_urls:[...], user_email, max_cursor}
    static func queryVideos(userEmail: String, url: String, maxCursor: Int) async throws -> [String: Any] {
        let dict = try await request("/v2/query/getvideosinfo", method: "POST", body: [
            "user_urls": [url],
            "user_email": userEmail,
            "max_cursor": maxCursor,
        ], auth: true, signed: true)
        let data = try expectData(dict)
        guard let d = data as? [String: Any] else { throw APIError.badResponse }
        return d
    }
}
