import Foundation
import CommonCrypto
import CryptoKit

/// 与 web 端 utils/signature.js 完全一致的签名与滑块加密工具
enum Crypto {

    /// SHA256 -> 小写 hex
    static func sha256Hex(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 数据签名：flatten -> 按键排序 -> k=v& 拼接 + timestamp=<秒>&key=<secret> -> SHA256
    /// 与 web 端 generateSignature 逻辑一致
    static func sign(_ data: [String: Any], secret: String, timestamp: Int) -> String {
        var pairs: [(String, String)] = []
        flatten(data, prefix: nil, into: &pairs)
        pairs.sort { $0.0 < $1.0 }
        let joined = pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let raw = "\(joined)&timestamp=\(timestamp)&key=\(secret)"
        return sha256Hex(raw)
    }

    /// 展平：数组 -> prefix.0/1/2...，字典 -> prefix.key（顶层无前缀）
    private static func flatten(_ value: Any, prefix: String?, into pairs: inout [(String, String)]) {
        let key: String
        if let p = prefix {
            key = p
        } else {
            key = ""
        }
        if let dict = value as? [String: Any] {
            for (k, v) in dict {
                let child = prefix == nil ? k : "\(prefix!).\(k)"
                flatten(v, prefix: child, into: &pairs)
            }
        } else if let array = value as? [Any] {
            for (i, v) in array.enumerated() {
                let child = "\(key).\(i)"
                flatten(v, prefix: child, into: &pairs)
            }
        } else {
            pairs.append((key, stringify(value)))
        }
    }

    /// 值转字符串：与 JS String(v) 一致（bool 小写、nil 空串）
    private static func stringify(_ value: Any) -> String {
        if value is NSNull { return "" }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber {
            // 避免整数被格式化成 12.0
            let objCType = String(cString: n.objCType)
            if objCType == "c" { return n.boolValue ? "true" : "false" }
            if objCType == "d" || objCType == "f" {
                if n.doubleValue == n.doubleValue.rounded() && abs(n.doubleValue) < 1e15 {
                    return String(Int64(n.doubleValue))
                }
                return String(n.doubleValue)
            }
            return n.stringValue
        }
        if let s = value as? String { return s }
        if let i = value as? Int { return String(i) }
        if let d = value as? Double { return String(d) }
        return String(describing: value)
    }

    /// AES-128-CBC + PKCS7 + Base64（滑块轨迹加密，与 web 端 encryptPayload 一致）
    /// key/iv 为 UTF-8 字符串（16 字节）
    static func aesCbcEncryptBase64(plain: String, key: String, iv: String) -> String? {
        guard let keyData = key.data(using: .utf8),
              let ivData = iv.data(using: .utf8),
              let plainData = plain.data(using: .utf8) else { return nil }
        let keyLength = kCCKeySizeAES128
        guard keyData.count == keyLength, ivData.count == kCCBlockSizeAES128 else { return nil }

        let dataLength = plainData.count
        let bufferSize = dataLength + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var moved: Int = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr -> CCCryptorStatus in
            plainData.withUnsafeBytes { plainPtr in
                keyData.withUnsafeBytes { keyPtr in
                    ivData.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyLength,
                            ivPtr.baseAddress,
                            plainPtr.baseAddress, dataLength,
                            bufferPtr.baseAddress, bufferSize,
                            &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return buffer.prefix(moved).base64EncodedString()
    }
}
