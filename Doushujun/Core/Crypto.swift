import Foundation      // 基础库：Data/String 编码
import CommonCrypto    // 系统 CommonCrypto：CC_SHA256/CC_MD5/CCCrypt

/// 通用加密/编码工具（对齐安卓 SignUtil + WebSignUtil + SliderCrypto）：
/// 三套签名体系——SHA-256 web 签名（新接口）、MD5 旧版签名（素材接口）、
/// AES-128-CBC（自研滑块轨迹加密），外加动态 JSON 访问器 J。
enum Crypto {

    // MARK: - 摘要（SHA-256 / MD5）

    /// SHA-256 摘要（hex 小写）：web 签名核心
    static func sha256Hex(_ s: String) -> String {
        let bytes = Array(s.utf8)                                        // 字符串转 UTF-8 字节数组
        var buf = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))  // 32 字节输出缓冲（DigestLength 是 Int32 需转 Int）
        _ = CC_SHA256(bytes, CC_LONG(bytes.count), &buf)                 // 执行摘要（结果写入 buf）
        return buf.map { String(format: "%02x", $0) }.joined()           // 每字节两位 hex 拼接
    }

    /// MD5 摘要（hex 小写）：旧版素材签名核心
    static func md5Hex(_ s: String) -> String {
        let bytes = Array(s.utf8)                                        // UTF-8 字节
        var buf = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))  // 16 字节输出缓冲
        _ = CC_MD5(bytes, CC_LONG(bytes.count), &buf)                    // 执行摘要
        return buf.map { String(format: "%02x", $0) }.joined()           // 转 hex 串
    }

    /// 16 位随机 nonce（a-z0-9，与安卓 genNonce 一致）
    static func genNonce() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")       // 字符池 36 个
        return String((0..<16).map { _ in chars.randomElement()! })      // 随机取 16 位拼接
    }

    /// 旧版 MD5 签名三元组（tools/video/remove_watermark 专用协议）
    /// signature = MD5("aweme_id=<id>&nonce=<n>&timestamp=<ms>" + 密钥)
    /// ⚠密钥必须是后端 MiniProgram::verifySignature 的小程序密钥（与安卓 SignUtil 一致），
    /// 不能用 web X-Signature 的 secretKey（两套体系各一个 key，混用=「签名验证失败」实证）
    static func legacySign(awemeId: String) -> (timestamp: String, nonce: String, signature: String) {
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))      // 当前毫秒时间戳
        let nonce = genNonce()                                           // 16 位随机数
        let sig = md5Hex("aweme_id=\(awemeId)&nonce=\(nonce)&timestamp=\(ts)" + Network.legacyKey)  // 固定序拼接+小程序密钥后 MD5
        return (ts, nonce, sig)                                          // 三元组一并返回（请求需原样携带）
    }

    // MARK: - web 端同款 X-Signature（WebSignUtil 移植）

    /// Java URLEncoder.encode 语义的表单编码：保留 a-zA-Z0-9 . - * _，空格→%20，其余 UTF-8 百分号编码
    static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics                         // 基础白名单：字母数字
        allowed.insert(charactersIn: ".-*_")                             // 追加 Java 保留的四个符号
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s  // 百分号编码（失败原样返回）
    }

    /// 请求体/参数展平为 key→value（嵌套转 a[b]，数组转 a[0]，PHP/JS 语义值转换）
    static func flatten(_ value: Any, prefix: String, out: inout [(String, String)]) {
        let strVal: (Any) -> String = { v in                             // 值→字符串（闭包，各类型对齐后端语义）
            switch v {
            case let b as Bool: return b ? "1" : "0"          // 布尔转 1/0（PHP 语义）
            case let n as NSNumber:
                // 整值数字去掉小数点（1.0 → "1"），与 PHP (string) 对齐
                if CFGetTypeID(n) == CFNumberGetTypeID() {    // 确认是数字而非布尔（Bool 也是 NSNumber）
                    let d = n.doubleValue                     // 取浮点值
                    if d == d.rounded() && abs(d) < 1e15 {    // 无小数部分且在安全整数范围内：
                        return String(Int64(d))               // 按整数输出（避免 1.0 字样）
                    }
                }
                return n.stringValue                          // 非整值：NSNumber 默认字符串化
            case is NSNull: return ""                        // null → 空串保留键
            case let s as String: return s                   // 字符串原样
            default: return String(describing: v)            // 兜底：描述字符串
            }
        }
        if let dict = value as? [String: Any] {              // 字典：递归展平，键排序保证签名稳定
            for k in dict.keys.sorted() {                    // 字典序遍历子键
                let p = prefix.isEmpty ? k : "\(prefix)[\(k)]"  // 拼路径：顶层直接用键名，嵌套用 a[b]
                flatten(dict[k]!, prefix: p, out: &out)      // 递归下钻
            }
        } else if let arr = value as? [Any] {                // 数组：下标路径 a[0]/a[1]
            for (i, el) in arr.enumerated() {                // 带序号遍历
                flatten(el, prefix: "\(prefix)[\(i)]", out: &out)  // 递归，路径带序号
            }
        } else {                                             // 叶子值：收进结果对
            out.append((prefix, strVal(value)))              // (完整路径, 字符串值)
        }
    }

    /// X-Signature：展平 → 字典序 → k=v& 连接（表单编码）→ 拼 &timestamp&key → SHA-256 hex
    static func webSignature(params: [String: Any], timestampSec: Int) -> String {
        var flat: [(String, String)] = []                // 展平结果容器
        flatten(params, prefix: "", out: &flat)          // 全参数展平（含嵌套）
        let query = flat.sorted { $0.0 < $1.0 }          // 按键字典序排序（签名稳定的前提）
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }  // 键值分别表单编码
            .joined(separator: "&")                      // & 连接成 query 串
        let raw = query + "&timestamp=\(timestampSec)&key=" + Network.secretKey  // 追加时间戳与密钥
        return sha256Hex(raw)                            // SHA-256 hex 即签名
    }

    // MARK: - AES-128-CBC（自研滑块轨迹加密，key/iv 为 UTF-8 字节）

    /// AES-128-CBC + PKCS7 加密并 Base64（无换行）：滑块轨迹数据上送前加密
    static func aesCBCEncryptBase64(_ plain: String, key: String, iv: String) -> String? {
        let data = Array(plain.utf8)                     // 明文字节
        let k = Array(key.utf8.prefix(16))               // 密钥取前 16 字节（128 位）
        let i = Array(iv.utf8.prefix(16))                // IV 取前 16 字节
        guard k.count == 16, i.count == 16 else { return nil }  // 长度不足：失败
        var out = Data(count: data.count + kCCBlockSizeAES128)  // 输出缓冲（明文+一个块，容纳填充）
        var moved = 0                                    // 实际写出字节数
        let status = out.withUnsafeMutableBytes { ob in  // 三层嵌套取裸指针调 CCCrypt
            data.withUnsafeBytes { db in                 // 明文指针
                i.withUnsafeBytes { ib in                // IV 指针
                    k.withUnsafeBytes { kb in            // 密钥指针
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),        // 加密/AES
                                CCOptions(kCCOptionPKCS7Padding), kb.baseAddress, kCCKeySizeAES128,  // PKCS7 填充/密钥/128 位
                                ib.baseAddress, db.baseAddress, data.count,                      // IV/明文/明文长
                                ob.baseAddress, ob.count, &moved)                        // 输出/容量/写出量
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }   // 加密失败：nil
        return out.prefix(moved).base64EncodedString() // 截取有效长度后 Base64（无换行 NO_WRAP）
    }
}

// MARK: - 动态 JSON 访问器（对齐安卓 org.json 手解析风格）

/// 轻量 JSON 包装：subscript 链式取字段，类型缺失时返回 nil 兜底。
/// 用法：j["data"]["list"][0]["name"].str ?? "默认值"——任意层级取空均安全。
struct J {
    let raw: Any  // 原始值（Dict/Array/String/Number/NSNull）

    /// 从 Data 构造（fragments 允许顶层标量）
    init(data: Data) throws {
        raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])  // 反序列化
    }
    /// 从任意值包装（子节点复用）
    init(_ any: Any) { raw = any }

    /// 字典取键：键不存在返回 NSNull 包装（链式安全的关键）
    subscript(key: String) -> J {
        if let d = raw as? [String: Any], let v = d[key] { return J(v) }  // 命中返回子节点
        return J(NSNull())                                                // 未命中：空节点
    }
    /// 数组取下标：越界返回 NSNull 包装
    subscript(i: Int) -> J {
        if let a = raw as? [Any], i >= 0 && i < a.count { return J(a[i]) }  // 界内返回子节点
        return J(NSNull())                                                  // 越界：空节点
    }

    /// 是否真实存在（非 NSNull 空节点）
    var exists: Bool { !(raw is NSNull) }

    /// 字符串取值：原生 String 直取；NSNumber 转串（布尔转 1/0 防误判）
    var str: String? {
        if let s = raw as? String { return s }              // 字符串直取
        if let n = raw as? NSNumber {
            // 避免布尔/数字被当字符串
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "1" : "0" }  // 布尔→1/0
            return n.stringValue                            // 数字→串
        }
        return nil                                          // 其他类型：nil
    }

    /// 整数取值：NSNumber（限 CFNumber，排除布尔）或数字字符串
    var int: Int? {
        if let n = raw as? NSNumber, CFGetTypeID(n) == CFNumberGetTypeID() { return n.intValue }  // 数字直取
        if let s = raw as? String { return Int(s) ?? Double(s).flatMap { Int($0) } }  // 字符串：先整后浮转整
        return nil
    }

    /// 浮点取值：NSNumber（限 CFNumber）或字符串
    var dbl: Double? {
        if let n = raw as? NSNumber, CFGetTypeID(n) == CFNumberGetTypeID() { return n.doubleValue }  // 数字直取
        if let s = raw as? String { return Double(s) }      // 字符串转浮点
        return nil
    }

    /// 布尔取值：NSNumber 直取；字符串认 "1"/"true"；默认 false
    var bool: Bool {
        if let n = raw as? NSNumber { return n.boolValue }                        // 数字/布尔直取
        if let s = raw as? String { return s == "1" || s.lowercased() == "true" }  // 字符串识别
        return false                                                              // 兜底 false
    }

    /// 数组取值：映射为 [J]，非数组返回空数组
    var arr: [J] { (raw as? [Any])?.map(J.init) ?? [] }

    /// 字典取值：所有键映射为 [String: J]
    var dict: [String: J] {
        var out: [String: J] = [:]                          // 结果容器
        if let d = raw as? [String: Any] { for k in d.keys { out[k] = self[k] } }  // 逐键包装
        return out
    }

    /// 万/亿缩写（对齐安卓 numFmt）：1.2亿/3.4万/整数字面/一位小数
    var numFmt: String {
        guard let d = dbl else { return str == nil ? "-" : str! }  // 非数字：字符串原样或 "-"
        let a = abs(d)                                             // 绝对值判量级
        if a >= 1e8 { return String(format: "%.1f亿", d / 1e8) }   // ≥1亿：一位小数+亿
        if a >= 1e4 { return String(format: "%.1f万", d / 1e4) }   // ≥1万：一位小数+万
        if d == d.rounded() { return String(Int64(d)) }            // 整值：直接输出
        return String(format: "%.1f", d)                           // 其他：一位小数
    }
}
