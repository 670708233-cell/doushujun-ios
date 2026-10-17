import SwiftUI

/// 查作品（web 端 v2/query/getvideosinfo 同款：主页作品列表 + 分页）
struct TiktokQueryView: View {
    @EnvironmentObject private var store: UserStore

    @State private var input = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage = ""

    @State private var userInfo: AuthorInfo?
    @State private var videos: [VideoItem] = []
    @State private var maxCursor = 0
    @State private var hasMore = false
    @State private var lastUrl = ""

    struct AuthorInfo {
        var nickname: String
        var uniqueId: String
        var signature: String
        var followerCount: String
        var followingCount: String
        var awemeCount: String
        var totalFavorited: String
        var avatarUrl: String
        var isVerified: Bool
    }

    struct VideoItem: Identifiable {
        var id: String { awemeId }
        var awemeId: String
        var desc: String
        var createTime: String
        var diggCount: String
        var commentCount: String
        var shareCount: String
        var playCount: String
        var coverUrl: String
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 输入卡
                    VStack(spacing: 12) {
                        HStack {
                            Text("抖音主页链接")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("余额 ¥\(String(format: "%.2f", store.balance))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                        }
                        TextField("粘贴抖音作者主页链接，如 https://v.douyin.com/xxx",
                                  text: $input, axis: .vertical)
                            .lineLimit(2...4)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                            .cornerRadius(10)

                        Button(action: { Task { await query(reset: true) } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                    Text("查询中...")
                                        .font(.system(size: 15, weight: .semibold))
                                } else {
                                    Image(systemName: "magnifyingglass")
                                    Text("查询作品")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || input.isEmpty)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // 作者信息卡
                    if let a = userInfo {
                        authorCard(a)
                    }

                    // 作品列表
                    if !videos.isEmpty {
                        VStack(spacing: 10) {
                            HStack {
                                Text("作品列表（\(videos.count)）")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            ForEach(videos) { v in
                                videoRow(v)
                            }
                            if hasMore {
                                Button(action: { Task { await query(reset: false) } }) {
                                    HStack {
                                        if isLoadingMore {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("加载更多")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isLoadingMore)
                            }
                        }
                        .padding(16)
                        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
    }

    private func authorCard(_ a: AuthorInfo) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let url = URL(string: a.avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(red: 0.15, green: 0.2, blue: 0.33)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(a.nickname)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        if a.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                        }
                    }
                    Text("@\(a.uniqueId)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                }
                Spacer()
            }
            HStack(spacing: 0) {
                statCell(label: "粉丝", value: a.followerCount)
                statCell(label: "关注", value: a.followingCount)
                statCell(label: "作品", value: a.awemeCount)
                statCell(label: "总获赞", value: a.totalFavorited)
            }
            if !a.signature.isEmpty {
                Text(a.signature)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private func videoRow(_ v: VideoItem) -> some View {
        HStack(spacing: 12) {
            if let url = URL(string: v.coverUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(red: 0.15, green: 0.2, blue: 0.33)
                }
                .frame(width: 74, height: 96)
                .cornerRadius(8)
                .clipped()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(v.desc.isEmpty ? "(无文案)" : v.desc)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(v.createTime)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))
                HStack(spacing: 12) {
                    iconStat(icon: "play.fill", value: v.playCount, color: Color(red: 0.4, green: 0.55, blue: 1.0))
                    iconStat(icon: "heart.fill", value: v.diggCount, color: Color(red: 0.95, green: 0.4, blue: 0.45))
                    iconStat(icon: "text.bubble.fill", value: v.commentCount, color: Color(red: 0.3, green: 0.75, blue: 0.42))
                    iconStat(icon: "arrowshape.turn.up.right.fill", value: v.shareCount, color: Color(red: 0.95, green: 0.62, blue: 0.24))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(red: 0.11, green: 0.16, blue: 0.28))
        .cornerRadius(12)
    }

    private func iconStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.72, green: 0.79, blue: 0.92))
        }
    }

    // MARK: - 查询

    private func query(reset: Bool) async {
        errorMessage = ""
        if reset {
            result_clear()
        }
        guard !input.isEmpty else { return }
        if reset { isLoading = true } else { isLoadingMore = true }
        defer {
            isLoading = false
            isLoadingMore = false
        }
        do {
            let d = try await API.queryVideos(userEmail: store.email,
                                              url: input,
                                              maxCursor: reset ? 0 : maxCursor)
            lastUrl = input
            parse(d, append: !reset)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func result_clear() {
        userInfo = nil
        videos = []
        maxCursor = 0
        hasMore = false
    }

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
            if let vs = it["videos"] as? [String: Any],
               let list = vs["list"] as? [Any] {
                if !append { videos = [] }
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
                maxCursor = API.toInt(vs["max_cursor"]) ?? maxCursor
                hasMore = (vs["has_more"] as? Bool) ?? ((API.toInt(vs["has_more"]) ?? 0) == 1)
            }
        }
    }

    private func coverOf(_ vd: [String: Any]) -> String {
        if let cover = vd["cover_url"] as? String { return cover }
        if let arr = vd["cover_url"] as? [Any], let first = arr.first as? String { return first }
        if let c = vd["cover"] as? [String: Any],
           let urls = c["url_list"] as? [Any], let first = urls.first as? String {
            return first
        }
        return ""
    }

    private func fmtCount(_ v: Any?) -> String {
        guard let n = API.toDouble(v) else { return "-" }
        if n >= 10000 { return String(format: "%.1fw", n / 10000) }
        if n == n.rounded() { return String(Int(n)) }
        return String(format: "%.0f", n)
    }

    private func fmtTime(_ v: Any?) -> String {
        guard let ts = API.toDouble(v), ts > 0 else { return "" }
        let date = Date(timeIntervalSince1970: ts)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
