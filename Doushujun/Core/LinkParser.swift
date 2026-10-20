import Foundation

/// 链接/ID 提取工具（逐行对齐安卓 LinkParser.kt）
enum LinkParser {

    struct VideoTarget {
        let id: String?   // 提取到的 19 位 ID
        let url: String?  // 处理后的输入（短链原样）
    }

    /// 提取 19 位视频/图文 ID
    static func extractAwemeId(_ input: String) -> String? {
        firstMatch("\\d{19}", input)
    }

    /// 分享短链 v.douyin.com（端上无法解析，交后端 parse-link）
    static func isShortLink(_ input: String) -> Bool {
        input.contains("v.douyin.com")
    }

    /// 提取分享文本中的 URL（分层：抖音域 → 任意 http → web 规则兜底）
    static func extractUrl(_ input: String) -> String {
        if let v = firstMatch("https?://[A-Za-z0-9.-]*douyin[.]com/[A-Za-z0-9/_?=&.%-]*", input) { return v }
        if let v = firstMatch("https?://[A-Za-z0-9/_?=&.%-]+", input) { return v }
        // WEB_URL 兜底：www/域名形态（简化为常见规则）
        if let v = firstMatch("[A-Za-z0-9-]+\\.[A-Za-z0-9.-]+(/\\S*)?", input) { return v }
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsUrl(_ input: String) -> Bool {
        match("[A-Za-z0-9-]+\\.[A-Za-z]{2,}", input)
    }

    /// 权重查询输入预处理（MS4/sec_uid=/user/路径/短链/纯数字账号）
    static func extractUserInput(_ raw: String) -> String {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.hasPrefix("MS4") { return input }
        if let g = firstGroup("sec_uid=([A-Za-z0-9_-]+)", input) { return g }
        if let g = firstGroup("/(?:share/)?user/([A-Za-z0-9_-]{20,})", input) { return g }
        return input
    }

    /// 作品类查询预处理
    static func extractVideoTarget(_ raw: String) -> VideoTarget {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = extractAwemeId(input) {
            let url = (isShortLink(input) || containsUrl(input)) ? extractUrl(input) : nil
            return VideoTarget(id: id, url: url)
        }
        return VideoTarget(id: nil, url: extractUrl(input))
    }

    // MARK: - Regex helpers

    private static func match(_ pattern: String, _ s: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func firstMatch(_ pattern: String, _ s: String) -> String? {
        s.range(of: pattern, options: .regularExpression).map { String(s[$0]) }
    }

    private static func firstGroup(_ pattern: String, _ s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, options: [], range: ns),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }
}
