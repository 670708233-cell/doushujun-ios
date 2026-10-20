import Foundation
import CommonCrypto

/// 通用加密/编码工具（对齐安卓 SignUtil + WebSignUtil + SliderCrypto）
enum Crypto {

    // MARK: - 摘要

    static func sha256Hex(_ s: String) -> String {
        digest(s, algo: CC_SHA256, len: CC_SHA256_DIGEST_LENGTH)
    }

    static func md5Hex(_ s: String) -> String {
        digest(s, algo: CC_MD5, len: CC_MD5_DIGEST_LENGTH)
    }

    private static func digest(_ s: String, algo: (_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?, len: Int32) -> String {
        let bytes = Array(s.utf8)
        var buf = [UInt8](repeating: 0, count: Int(len))
        algo(bytes, CC_LONG(bytes.count), &buf)
        return buf.map { String(format: "%02x", $0) }.joined()
    }

    /// 16 位随机 nonce（a-z0-9，与安卓 genNonce 一致）
    static func genNonce() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<16).map { _ in chars.randomElement()! })
    }

    /// 旧版 MD5 签名三元组（tools/video/remove_watermark 专用协议）
    /// signature = MD5("aweme_id=<id>&nonce=<n>&timestamp=<ms>" + secretKey)
    static func legacySign(awemeId: String) -> (timestamp: String, nonce: String, signature: String) {
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = genNonce()
        let sig = md5Hex("aweme_id=\(awemeId)&nonce=\(nonce)&timestamp=\(ts)" + Network.secretKey)
        return (ts, nonce, sig)
    }

    // MARK: - web 端同款 X-Signature（WebSignUtil 移植）

    /// Java URLEncoder.encode 语义的表单编码：保留 a-zA-Z0-9 . - * _，空格→%20，其余 UTF-8 百分号编码
    static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-*_")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    /// 请求体/参数展平为 key→value（嵌套转 a[b]，数组转 a[0]，PHP/JS 语义值转换）
    static func flatten(_ value: Any, prefix: String, out: inout [(String, String)]) {
        let strVal: (Any) -> String = { v in
            switch v {
            case let b as Bool: return b ? "1" : "0"          // 布尔转 1/0（PHP 语义）
            case let n as NSNumber:
                // 整值数字去掉小数点（1.0 → "1"），与 PHP (string) 对齐
                if CFGetTypeID(n) == CFNumberGetTypeID() {
                    let d = n.doubleValue
                    if d == d.rounded() && abs(d) < 1e15 {
                        return String(Int64(d))
                    }
                }
                return n.stringValue
            case is NSNull: return ""                        // null → 空串保留键
            case let s as String: return s
            default: return String(describing: v)
            }
        }
        if let dict = value as? [String: Any] {
            for k in dict.keys.sorted() {
                let p = prefix.isEmpty ? k : "\(prefix)[\(k)]"
                flatten(dict[k]!, prefix: p, out: &out)
            }
        } else if let arr = value as? [Any] {
            for (i, el) in arr.enumerated() {
                flatten(el, prefix: "\(prefix)[\(i)]", out: &out)
            }
        } else {
            out.append((prefix, strVal(value)))
        }
    }

    /// X-Signature：展平 → 字典序 → k=v& 连接（表单编码）→ 拼 &timestamp&key → SHA-256 hex
    static func webSignature(params: [String: Any], timestampSec: Int) -> String {
        var flat: [(String, String)] = []
        flatten(params, prefix: "", out: &flat)
        let query = flat.sorted { $0.0 < $1.0 }
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
        let raw = query + "&timestamp=\(timestampSec)&key=" + Network.secretKey
        return sha256Hex(raw)
    }

    // MARK: - AES-128-CBC（自研滑块轨迹加密，key/iv 为 UTF-8 字节）

    static func aesCBCEncryptBase64(_ plain: String, key: String, iv: String) -> String? {
        let data = Array(plain.utf8)
        let k = Array(key.utf8.prefix(16))
        let i = Array(iv.utf8.prefix(16))
        guard k.count == 16, i.count == 16 else { return nil }
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var moved = 0
        let status = out.withUnsafeMutableBytes { ob in
            data.withUnsafeBytes { db in
                i.withUnsafeBytes { ib in
                    k.withUnsafeBytes { kb in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding), kb.baseAddress, kCCKeySizeAES128,
                                ib.baseAddress, db.baseAddress, data.count,
                                ob.baseAddress, ob.count, &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return out.prefix(moved).base64EncodedString() // 无换行 NO_WRAP
    }
}

// MARK: - 动态 JSON 访问器（对齐安卓 org.json 手解析风格）

/// 轻量 JSON 包装：subscript 链式取字段，类型缺失时返回 nil 兜底
struct J {
    let raw: Any

    init(data: Data) throws {
        raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
    init(_ any: Any) { raw = any }

    subscript(key: String) -> J {
        if let d = raw as? [String: Any], let v = d[key] { return J(v) }
        return J(NSNull())
    }
    subscript(i: Int) -> J {
        if let a = raw as? [Any], i >= 0 && i < a.count { return J(a[i]) }
        return J(NSNull())
    }

    var exists: Bool { !(raw is NSNull) }
    var str: String? {
        if let s = raw as? String { return s }
        if let n = raw as? NSNumber {
            // 避免布尔/数字被当字符串
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "1" : "0" }
            return n.stringValue
        }
        return nil
    }
    var int: Int? {
        if let n = raw as? NSNumber, CFGetTypeID(n) == CFNumberGetTypeID() { return n.intValue }
        if let s = raw as? String { return Int(s) ?? Int(Double(s).map { Int($0) } ?? nil) }
        return nil
    }
    var dbl: Double? {
        if let n = raw as? NSNumber, CFGetTypeID(n) == CFNumberGetTypeID() { return n.doubleValue }
        if let s = raw as? String { return Double(s) }
        return nil
    }
    var bool: Bool {
        if let n = raw as? NSNumber { return n.boolValue }
        if let s = raw as? String { return s == "1" || s.lowercased() == "true" }
        return false
    }
    var arr: [J] { (raw as? [Any])?.map(J.init) ?? [] }
    var dict: [String: J] {
        var out: [String: J] = [:]
        if let d = raw as? [String: Any] { for k in d.keys { out[k] = self[k] } }
        return out
    }
    /// 万/亿缩写（对齐安卓 numFmt）
    var numFmt: String {
        guard let d = dbl else { return str == nil ? "-" : str! }
        let a = abs(d)
        if a >= 1e8 { return String(format: "%.1f亿", d / 1e8) }
        if a >= 1e4 { return String(format: "%.1f万", d / 1e4) }
        if d == d.rounded() { return String(Int64(d)) }
        return String(format: "%.1f", d)
    }
}
