import SwiftUI

// ============================================================================
// TiktokQueryView —— 查作品（web 端 v2/query/getvideosinfo 同款）
// 输入主页链接 → 作者信息卡 + 作品列表（播放/点赞/评论/分享）+ 分页加载
// ============================================================================

struct TiktokQueryView: View {

    @EnvironmentObject private var store: UserStore   // 全局状态（邮箱/余额）

    // MARK: - 状态

    @State private var input = ""                     // 主页链接输入
    @State private var isLoading = false              // 首次查询中
    @State private var isLoadingMore = false          // 加载更多中
    @State private var errorMessage = ""              // 错误提示

    @State private var userInfo: AuthorInfo?          // 作者信息
    @State private var videos: [VideoItem] = []       // 作品列表
    @State private var maxCursor = 0                  // 分页游标
    @State private var hasMore = false                // 是否还有下一页

    /// 作者信息模型
    struct AuthorInfo {
        var nickname: String                          // 昵称
        var uniqueId: String                          // 抖号
        var signature: String                         // 个性签名
        var followerCount: String                     // 粉丝数
        var followingCount: String                    // 关注数
        var awemeCount: String                        // 作品数
        var totalFavorited: String                    // 总获赞
        var avatarUrl: String                         // 头像
        var isVerified: Bool                          // 是否认证
    }

    /// 单条作品模型
    struct VideoItem: Identifiable {
        var id: String { awemeId }                    // aweme_id 作唯一 ID
        var awemeId: String
        var desc: String                              // 文案
        var createTime: String                        // 发布日期
        var diggCount: String                         // 点赞
        var commentCount: String                      // 评论
        var shareCount: String                        // 分享
        var playCount: String                         // 播放
        var coverUrl: String                          // 封面图
    }

    var body: some View {
        ZStack {
            CyberBackground()                              // 统一深空背景

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 顶部标题区 ----
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("作品数据分析")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .gradientText(Theme.cyber)
                            Text("拉取账号主页作品与互动数据")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSub)
                        }
                        Spacer()
                        // 余额胶囊
                        HStack(spacing: 5) {
                            Image(systemName: "creditcard.fill").font(.system(size: 11))
                            Text(String(format: "%.2f", store.balance))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.green.opacity(0.12)))
                        .overlay(Capsule().stroke(Theme.green.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // ---- 输入卡 ----
                    VStack(spacing: 14) {
                        SectionHeader(icon: "video.badge.waveform", title: "作者主页")

                        // 多行链接输入
                        TextField("粘贴抖音作者主页链接，如 https://v.douyin.com/xxx",
                                  text: $input, axis: .vertical)
                            .lineLimit(2...4)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMain)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(input.isEmpty ? Theme.cardStroke : Theme.blue.opacity(0.5), lineWidth: 1))

                        // 查询按钮
                        Button {
                            Task { await query(reset: true) }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                    Text("查询中...")
                                } else {
                                    Image(systemName: "sparkle.magnifyingglass") // 搜索星标
                                    Text("查询作品")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.cyber, height: 50))
                        .disabled(isLoading || input.isEmpty)

                        // 错误提示
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13)).foregroundStyle(Theme.red)
                                Text(errorMessage).font(.system(size: 13)).foregroundColor(Theme.red)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.10)))
                        }
                    }
                    .glassCard(radius: 22, padding: 18)
                    .padding(.horizontal, 18)

                    // ---- 作者信息卡 ----
                    if let a = userInfo {
                        authorCard(a)
                    }

                    // ---- 作品列表卡 ----
                    if !videos.isEmpty {
                        VStack(spacing: 10) {
                            SectionHeader(icon: "list.bullet.rectangle.fill",
                                          title: "作品列表",
                                          trailing: "共 \(videos.count) 条")
                            ForEach(videos) { v in
                                videoRow(v)                        // 单条作品行
                            }
                            // 加载更多按钮（还有下一页才显示）
                            if hasMore {
                                Button {
                                    Task { await query(reset: false) }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isLoadingMore {
                                            ProgressView().tint(Theme.cyan)
                                            Text("加载中...")
                                        } else {
                                            Image(systemName: "arrow.down.circle")
                                            Text("加载更多")
                                        }
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06)))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.cardStroke, lineWidth: 1))
                                }
                                .disabled(isLoadingMore)
                            }
                        }
                        .glassCard(radius: 22, padding: 18)
                        .padding(.horizontal, 18)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
    }

    // MARK: - 作者信息卡

    private func authorCard(_ a: AuthorInfo) -> some View {
        VStack(spacing: 12) {
            // 头像 + 昵称 + 抖号
            HStack(spacing: 12) {
                if let url = URL(string: a.avatarUrl), !a.avatarUrl.isEmpty {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.08))
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.purple.opacity(0.6), lineWidth: 1.5)) // 霓虹描边
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(a.nickname)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textMain)
                        if a.isVerified {                              // 认证徽章
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.cyan)
                        }
                    }
                    Text("@\(a.uniqueId)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSub)
                }
                Spacer()
            }
            // 四格数据：粉丝/关注/作品/总获赞
            HStack(spacing: 0) {
                statCell(label: "粉丝", value: a.followerCount, tint: Theme.cyan)
                statCell(label: "关注", value: a.followingCount, tint: Theme.blue)
                statCell(label: "作品", value: a.awemeCount, tint: Theme.purple)
                statCell(label: "总获赞", value: a.totalFavorited, tint: Theme.amber)
            }
            // 个性签名
            if !a.signature.isEmpty {
                Text(a.signature)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .glassCard(radius: 22, padding: 18)
        .padding(.horizontal, 18)
    }

    /// 数据小格：彩色数字 + 灰色标签
    private func statCell(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .gradientText(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                             startPoint: .top, endPoint: .bottom))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 单条作品行

    private func videoRow(_ v: VideoItem) -> some View {
        HStack(spacing: 12) {
            // 封面图（霓虹描边圆角）
            if let url = URL(string: v.coverUrl), !v.coverUrl.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .frame(width: 74, height: 96)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1))
                .clipped()
            }
            // 文案 + 日期 + 四指标
            VStack(alignment: .leading, spacing: 6) {
                Text(v.desc.isEmpty ? "(无文案)" : v.desc)          // 作品文案
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textMain)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(v.createTime)                                  // 发布日期
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textDim)
                HStack(spacing: 12) {
                    iconStat(icon: "play.fill", value: v.playCount, color: Theme.cyan)          // 播放
                    iconStat(icon: "heart.fill", value: v.diggCount, color: Theme.red)          // 点赞
                    iconStat(icon: "text.bubble.fill", value: v.commentCount, color: Theme.green) // 评论
                    iconStat(icon: "arrowshape.turn.up.right.fill", value: v.shareCount, color: Theme.amber) // 分享
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))                    // 行内淡底
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    /// 彩色图标+数值
    private func iconStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textSub)
        }
    }

    // MARK: - 查询

    private func query(reset: Bool) async {
        errorMessage = ""
        if reset {                                                   // 首查清空状态
            userInfo = nil
            videos = []
            maxCursor = 0
            hasMore = false
        }
        guard !input.isEmpty else { return }
        if reset { isLoading = true } else { isLoadingMore = true }  // 两种 loading
        defer {
            isLoading = false
            isLoadingMore = false
        }
        do {
            // POST /v2/query/getvideosinfo（JWT + 签名，游标分页）
            let d = try await API.queryVideos(userEmail: store.email,
                                              url: input,
                                              maxCursor: reset ? 0 : maxCursor)
            parse(d, append: !reset)                                 // 翻页=追加
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 解析响应：data[].{status, user_info, videos{list, max_cursor, has_more}}
    private func parse(_ d: [String: Any], append: Bool) {
        guard let arr = (d["data"] as? [Any]) ?? (d["results"] as? [Any]) else {
            errorMessage = "未获取到作品数据"
            return
        }
        for item in arr {
            guard let it = item as? [String: Any] else { continue }
            let status = API.toStr(it["status"]).lowercased()
            if status != "success" && status != "ok" && status != "" {
                errorMessage = API.toStr(it["msg"], fallback: "该账号查询失败")
                continue
            }
            // ---- 作者信息 ----
            if let u = it["user_info"] as? [String: Any] {
                userInfo = AuthorInfo(
                    nickname: API.toStr(u["nickname"]),
                    uniqueId: API.toStr(u["unique_id"]),
                    signature: API.toStr(u["signature"]),
                    followerCount: fmtCount(u["follower_count"]),
                    followingCount: fmtCount(u["following_count"]),
                    awemeCount: fmtCount(u["aweme_count"]),
                    totalFavorited: fmtCount(u["total_favorited"]),
                    avatarUrl: API.toStr(u["avatar_url"]),
                    isVerified: (API.toInt(u["is_verified"]) ?? 0) == 1
                )
            }
            // ---- 作品列表 ----
            if let vs = it["videos"] as? [String: Any],
               let list = vs["list"] as? [Any] {
                if !append { videos = [] }                           // 首查覆盖
                for v in list {
                    guard let vd = v as? [String: Any] else { continue }
                    videos.append(VideoItem(
                        awemeId: API.toStr(vd["aweme_id"]),
                        desc: API.toStr(vd["desc"]),
                        createTime: fmtTime(vd["create_time"]),
                        diggCount: fmtCount(vd["digg_count"]),
                        commentCount: fmtCount(vd["comment_count"]),
                        shareCount: fmtCount(vd["share_count"]),
                        playCount: fmtCount(vd["play_count"]),
                        coverUrl: coverOf(vd)
                    ))
                }
                maxCursor = API.toInt(vs["max_cursor"]) ?? maxCursor // 更新游标
                hasMore = (vs["has_more"] as? Bool) ?? ((API.toInt(vs["has_more"]) ?? 0) == 1)
            }
        }
    }

    /// 兼容多种封面字段形态（字符串/数组/对象 url_list）
    private func coverOf(_ vd: [String: Any]) -> String {
        if let cover = vd["cover_url"] as? String { return cover }
        if let arr = vd["cover_url"] as? [Any], let first = arr.first as? String { return first }
        if let c = vd["cover"] as? [String: Any],
           let urls = c["url_list"] as? [Any], let first = urls.first as? String {
            return first
        }
        return ""
    }

    /// 数量格式化：过万显示 x.xw
    private func fmtCount(_ v: Any?) -> String {
        guard let n = API.toDouble(v) else { return "-" }
        if n >= 10000 { return String(format: "%.1fw", n / 10000) }
        if n == n.rounded() { return String(Int(n)) }
        return String(format: "%.0f", n)
    }

    /// 时间戳 → yyyy-MM-dd
    private func fmtTime(_ v: Any?) -> String {
        guard let ts = API.toDouble(v), ts > 0 else { return "" }
        let date = Date(timeIntervalSince1970: ts)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
