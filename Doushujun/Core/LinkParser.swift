import Foundation  // 基础库：字符串/正则（NSRegularExpression 所在）

/// 链接/ID 提取工具（逐行对齐安卓 LinkParser.kt）：
/// 负责把用户粘贴的分享文本（口令/短链/长链/sec_uid 链接）清洗成
/// 后端接口需要的形态：19 位作品 ID、可访问 URL、sec_uid 等。
enum LinkParser {

    /// 作品类查询的解析产物：ID 与 URL 至少有一个非空
    struct VideoTarget {
        let id: String?   // 提取到的 19 位 ID（有 ID 时查询更精确）
        let url: String?  // 处理后的输入（短链原样交后端解析；无 ID 时必填）
    }

    /// 提取 19 位视频/图文 ID：抖音作品 ID 固定 19 位数字，全文正则搜索第一处
    static func extractAwemeId(_ input: String) -> String? {
        firstMatch("\\d{19}", input)  // 连续 19 位数字即视为作品 ID
    }

    /// 分享短链 v.douyin.com（端上无法解析，交后端 parse-link）：仅做包含判断
    static func isShortLink(_ input: String) -> Bool {
        input.contains("v.douyin.com")  // 短链域名特征
    }

    /// 提取分享文本中的 URL（分层：抖音域 → 任意 http → web 规则兜底）
    static func extractUrl(_ input: String) -> String {
        if let v = firstMatch("https?://[A-Za-z0-9.-]*douyin[.]com/[A-Za-z0-9/_?=&.%-]*", input) { return v }  // 第一优先：抖音域完整 URL
        if let v = firstMatch("https?://[A-Za-z0-9/_?=&.%-]+", input) { return v }  // 第二优先：任意 http(s) 链接
        // WEB_URL 兜底：www/域名形态（简化为常见规则）
        if let v = firstMatch("[A-Za-z0-9-]+\\.[A-Za-z0-9.-]+(/\\S*)?", input) { return v }  // 第三优先：不带协议的域名形态
        return input.trimmingCharacters(in: .whitespacesAndNewlines)  // 全都不匹配：原文去首尾空白返回
    }

    /// 判断文本中是否含 URL（域名特征：xx.yy 两段以上字母数字）
    static func containsUrl(_ input: String) -> Bool {
        match("[A-Za-z0-9-]+\\.[A-Za-z]{2,}", input)  // 宽松匹配任意域名
    }

    /// 权重查询输入预处理（MS4/sec_uid=/user/路径/短链/纯数字账号）
    static func extractUserInput(_ raw: String) -> String {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)  // 先去首尾空白
        if input.hasPrefix("MS4") { return input }  // 已是 MS4 开头的用户串：原样使用
        if let g = firstGroup("sec_uid=([A-Za-z0-9_-]+)", input) { return g }  // 从 URL 参数里抓 sec_uid 值
        if let g = firstGroup("/(?:share/)?user/([A-Za-z0-9_-]{20,})", input) { return g }  // 从 /user/ 或 /share/user/ 路径里抓长 ID
        return input  // 其余形态（纯数字账号/昵称）：原文返回交后端处理
    }

    /// 作品类查询预处理：优先提 19 位 ID，其次提 URL
    static func extractVideoTarget(_ raw: String) -> VideoTarget {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)  // 清洗输入
        if let id = extractAwemeId(input) {  // 能提取到 19 位 ID：
            let url = (isShortLink(input) || containsUrl(input)) ? extractUrl(input) : nil  // 同时有链接则附上（短链需后端展开）
            return VideoTarget(id: id, url: url)  // ID+URL 双参返回
        }
        return VideoTarget(id: nil, url: extractUrl(input))  // 无 ID：仅 URL 返回
    }

    // MARK: - Regex helpers（正则辅助三件套）

    /// 是否匹配：全文搜索正则命中即 true
    private static func match(_ pattern: String, _ s: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil  // 正则模式搜索
    }

    /// 首个匹配串：取第一处命中文本，无命中返回 nil
    private static func firstMatch(_ pattern: String, _ s: String) -> String? {
        s.range(of: pattern, options: .regularExpression).map { String(s[$0]) }  // Range 转回字符串
    }

    /// 首个捕获组：取正则第 1 分组内容（需要 NSRegularExpression 才支持分组）
    private static func firstGroup(_ pattern: String, _ s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }  // 编译正则失败→nil
        let ns = NSRange(s.startIndex..., in: s)  // 全文 NSRange
        guard let m = re.firstMatch(in: s, options: [], range: ns),
              m.numberOfRanges > 1,  // 确保存在第 1 分组
              let r = Range(m.range(at: 1), in: s) else { return nil }  // 分组区间转 Swift Range
        return String(s[r])  // 分组文本
    }
}
