import SwiftUI

/// AI 作品优化分析页（对齐安卓 WorkScreen.kt）
struct WorkView: View {
    var onOpenHistory: () -> Void
    @ObservedObject private var bus = SessionBus.shared

    @State private var input = ""
    @State private var loading = false
    @State private var error = ""
    @State private var result: J? = nil
    @State private var resultTitle: String? = nil
    @State private var showHelp = false
    @State private var history: [SessionStore.HistoryEntry] = []
    @State private var aiAnalyzing = false
    @State private var aiMsg: String? = nil
    @State private var aiError = ""
    @State private var recentList: [J] = []
    @State private var snackbar = ""
    @State private var tip: (String, String)? = nil

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()
                    GradientBanner(title: "AI作品优化分析", subtitle: "播放量、点赞评论等全维度数据 + AI 优化建议")

                    // 查询输入卡
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            QuotaRow()
                            TextField("粘贴作品分享链接或19位ID", text: $input)
                                .font(.system(size: 14)).foregroundColor(T.textMain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                            HStack(spacing: 10) {
                                PrimaryButton(title: "立即分析", loading: loading) { doQuery() }
                                Button { onOpenHistory() } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(T.primary).frame(width: 48, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                                }
                                Button { withAnimation { showHelp.toggle() } } label: {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(T.textSub).frame(width: 42, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                                }
                            }
                            Text("✨ 支持AI作品分析")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(T.primary)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(T.primary.opacity(0.12)))
                                .frame(maxWidth: .infinity)
                            if showHelp {
                                Text("① 复制抖音APP分享的作品链接或输入19位作品ID\n② 点击「立即分析」开始查询\n③ 查询完成后点击「AI作品分析」获取优化建议\n\n数据为发布以来累计值，建议先看播放/推荐量判断流量池层级")
                                    .font(.system(size: 12)).foregroundColor(T.textSub)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.06)))
                            }
                            ErrorText(text: error)
                        }
                    }

                    if result == nil {
                        recentSection
                    } else {
                        resultSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            if let t = tip { tipDialog(t) }
        }
        .snackbar($snackbar)
        .onAppear {
            history = SessionStore.history(SessionStore.workHistoryKey)
            loadRecent()
        }
        .onChange(of: bus.pendingWorkId) { id in
            if let id = id {
                bus.pendingWorkId = nil
                input = id
                analyzeWorkById(id)
            }
        }
    }

    // MARK: - 最近分析（服务端前 3）

    @ViewBuilder
    private var recentSection: some View {
        if !recentList.isEmpty {
            SectionTitle(text: "最近分析")
            ForEach(Array(recentList.prefix(3).enumerated()), id: \.offset) { _, r in
                let cover = r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str
                Button {
                    if let id = r["aweme_id"].str {
                        input = id
                        doQuery()
                    }
                } label: {
                    GlassCard(padding: 12) {
                        HStack(spacing: 12) {
                            NetImage(url: cover, width: 56, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 4) {
                                Text({ let d = r["desc"].str ?? ""; return d.isEmpty ? "未命名作品" : d }())
                                    .font(.system(size: 13, weight: .medium)).foregroundColor(T.textMain).lineLimit(2)
                                Text("账号：\(r["owner_handle"].str ?? r["author_unique_id"].str ?? "-")")
                                    .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                Text("查询时间：\(String((r["last_query_time"].str ?? "").prefix(16)))")
                                    .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
            }
        } else if !history.isEmpty {
            SectionTitle(text: "最近分析")
            GlassCard {
                HStack(spacing: 8) {
                    ForEach(history.prefix(3)) { h in
                        Button {
                            input = h.id
                            doQuery()
                        } label: {
                            Text(String(h.id.prefix(18)))
                                .font(.system(size: 12)).foregroundColor(T.primary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(T.primary.opacity(0.10)))
                                .overlay(Capsule().stroke(T.primary.opacity(0.3), lineWidth: 1))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        Button { onOpenHistory() } label: {
            GlassCard(padding: 14) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(T.primary)
                    Text("查询历史（与 Web 端同步）").font(.system(size: 14)).foregroundColor(T.textMain)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                }
            }
        }
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultSection: some View {
        let r = result!

        // 作品信息
        SectionTitle(text: "作品信息")
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    NetImage(url: r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str, width: 86, height: 114)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 6) {
                        Text({ let d = r["desc"].str ?? ""; return d.isEmpty ? "无描述" : d }())
                            .font(.system(size: 13)).foregroundColor(T.textMain).lineLimit(3)
                        Text("分类：\(r["video_category_desc"].str ?? "无")\n形式：\(r["orientation"].str ?? "未知")    时长：\(r["duration_formatted"].str ?? "未知")\(resolution(r))")
                            .font(.system(size: 11)).foregroundColor(T.textSub)
                        if let tp = r["traffic_pool_desc"].str, !tp.isEmpty {
                            Text("流量池：\(tp)").font(.system(size: 11)).foregroundColor(T.warn)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let aiTitle = r["ai_title"].str, !aiTitle.isEmpty {
                    Text("AI 推荐标题").font(.system(size: 11)).foregroundColor(T.textSub)
                    Text(aiTitle.replacingOccurrences(of: "|", with: "\n"))
                        .font(.system(size: 13)).foregroundColor(T.warn)
                }
                infoLine("作品ID", r["aweme_id"].str ?? "")
            }
        }

        // 作者信息
        let author = r["author_info"]
        let aField: (String) -> String = { k in
            let v = r[k].str
            if let v = v, !v.isEmpty { return v }
            return author[k].str ?? ""
        }
        SectionTitle(text: "作者信息")
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(aField("owner_nickname"))  @\(aField("owner_handle"))")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
                infoLine("用户签名", aField("signature"))
                infoLine("粉丝数", aField("follower_count"))
                infoLine("总获赞数", aField("total_favorited"))
                infoLine("认证类型", { let v = aField("verification_type_desc"); return v.isEmpty ? "未认证" : v }())
                if let vd = (r["verification_desc"].str ?? author["verification_desc"].str), !vd.isEmpty {
                    infoLine("认证描述", vd)
                } else if let ev = (r["enterprise_verify_reason"].str ?? author["enterprise_verify_reason"].str), !ev.isEmpty {
                    infoLine("认证描述", ev)
                }
            }
        }

        // 数据表现
        let st = r["stats"].exists ? r["stats"] : r
        SectionTitle(text: "数据表现")
        GlassCard {
            VStack(spacing: 2) {
                ForEach(MetricOrder, id: \.key) { m in
                    if let v = metricText(st, m.key) {
                        HStack {
                            tipIcon("播放/推荐量" == m.label || metricName(m.key) != nil, m.label)
                            Text(m.label).font(.system(size: 13)).foregroundColor(T.textSub)
                            Spacer()
                            Text(v).font(.system(size: 13)).foregroundColor(T.textMain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let er = r["engagement_rate_formatted"].str, !er.isEmpty {
                    HStack {
                        tipIcon(true, "互动率")
                        Text("互动率").font(.system(size: 13)).foregroundColor(T.textSub)
                        Spacer()
                        Text(er).font(.system(size: 13)).foregroundColor(T.primary)
                    }
                    .padding(.vertical, 4)
                }
                let wr = r["weighted_engagement_rate_formatted"].str
                    ?? r["weighted_engagement_rate"].dbl.map { String(format: "%.2f%%", $0) }
                if let wr = wr, !wr.isEmpty {
                    HStack {
                        tipIcon(true, "加权互动率")
                        Text("加权互动率").font(.system(size: 13)).foregroundColor(T.textSub)
                        Spacer()
                        Text(wr).font(.system(size: 13)).foregroundColor(T.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        // 互动率画像雷达图
        if let play = st["play_count"].dbl ?? st["recommend_count"].dbl, play > 0 {
            SectionTitle(text: "互动率画像")
            GlassCard {
                VStack(spacing: 8) {
                    RadarChartView(
                        values: radarValues(st, play),
                        labels: radarLabels(st, play)
                    )
                    Text("顶点为实际互动率 ÷ 行业参考基准：中圈=基准，外圈=2倍基准（封顶）")
                        .font(.system(size: 10)).foregroundColor(T.textSub)
                }
            }
        }

        // 时间信息
        let qt = r["last_query_time"].str, ct = r["create_time"].str
        if qt != nil || ct != nil {
            SectionTitle(text: "时间信息")
            GlassCard {
                VStack(spacing: 4) {
                    if let q = qt, !q.isEmpty { infoLine("查询时间", timeText(q)) }
                    if let c = ct, !c.isEmpty { infoLine("发布时间", timeText(c)) }
                }
            }
        }

        // 带货信息
        let isProduct = r["is_product_video"].bool
        if isProduct {
            SectionTitle(text: "带货信息")
            GlassCard {
                VStack(spacing: 4) {
                    infoLine("是否带货", "是")
                    if let pd = r["product_details"].raw as? [String: Any] {
                        let p = J(pd)
                        if let v = p["product_type"].str { infoLine("产品类型", v) }
                        if let sc = p["sales_clues"].raw as Any? {
                            infoLine("销售线索", salesClues(sc))
                        }
                        if let v = p["product_info"]["title"].str { infoLine("商品标题", v) }
                        if let v = p["product_info"]["sales"].int { infoLine("已售", String(v)) }
                        let promos = p["promotional_info"].arr.compactMap(\.str)
                        if !promos.isEmpty { infoLine("促销信息", promos.joined(separator: "、")) }
                    }
                }
            }
        }

        // 热搜词
        let hotWords = parseHotWords(r["hot_words"])
        if !hotWords.isEmpty {
            SectionTitle(text: "热搜词")
            GlassCard {
                Text(hotWords.joined(separator: "、")).font(.system(size: 13)).foregroundColor(T.textMain)
            }
        }

        // 作品状态
        SectionTitle(text: "作品状态")
        GlassCard {
            VStack(spacing: 4) {
                infoLine("查询状态", (r["status"].str ?? "") == "error" ? "✗ 失败" : "✓ 成功")
                let limited = r["is_limited"].bool
                infoLine("限流", limited ? "⚠ 已限流" : "正常", color: limited ? T.danger : .green)
                if limited, let reason = r["limit_reason"].str, !reason.isEmpty {
                    Text("限流原因：\(reason)").font(.system(size: 12)).foregroundColor(Color(hex: "FB7185"))
                }
            }
        }

        // AI 作品分析
        SectionTitle(text: "AI 作品分析")
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                PrimaryButton(title: aiAnalyzing ? "分析中…" : "AI作品分析",
                              loading: aiAnalyzing, enabled: !aiAnalyzing) { doAiAnalyze() }
                if let m = aiMsg { Text(m).font(.system(size: 12)).foregroundColor(T.textSub) }
                if !aiError.isEmpty { Text(aiError).font(.system(size: 12)).foregroundColor(Color(hex: "FB7185")) }
            }
        }

        // AI 优化建议（8 字段）
        aiSectionsView(r)
    }

    @ViewBuilder
    private func aiSectionsView(_ r: J) -> some View {
        // AI 字段优先取轮询结果（aiResultData），无则回退查询结果
        let aiData = aiResultData?.exists == true ? aiResultData! : r
        let fields: [(String, String)] = [
            ("optimization_tips", "💡 优化建议"),
            ("content_evaluation", "📋 内容质量评分"),
            ("data_analysis", "📊 数据表现分析"),
            ("optimization_directions", "🎯 优化方向"),
            ("hashtag_suggestions", "#️⃣ 推荐话题标签"),
            ("posting_time_advice", "⏰ 发布时间建议"),
            ("competition_analysis", "⚔️ 竞品对标分析"),
        ]
        let hasAny = fields.contains { !normalizedLines(aiData[$0.0]).isEmpty }
        if hasAny {
            SectionTitle(text: "AI 优化建议")
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fields, id: \.0) { f in
                        let lines = normalizedLines(aiData[f.0])
                        if !lines.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.1).font(.system(size: 13, weight: .semibold)).foregroundColor(T.primary)
                                ForEach(lines, id: \.self) { line in
                                    Text("· \(line)").font(.system(size: 13)).foregroundColor(T.textMain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 小组件

    private func infoLine(_ label: String, _ value: String, color: Color = T.textMain) -> some View {
        HStack(alignment: .top) {
            tipIcon(WorkTips[label] != nil, label)
            Text(label).font(.system(size: 13)).foregroundColor(T.textSub)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13)).foregroundColor(color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }

    private func tipIcon(_ show: Bool, _ label: String) -> some View {
        Group {
            if show, let body = WorkTips[label] {
                Button { tip = (label, body) } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 10)).foregroundColor(T.textSub.opacity(0.75))
                }
                .padding(.trailing, 2)
            }
        }
    }

    private func tipDialog(_ t: (String, String)) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { tip = nil }
            VStack(alignment: .leading, spacing: 12) {
                Text(t.0).font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)
                Text(t.1).font(.system(size: 13)).foregroundColor(T.textSub)
                Button { tip = nil } label: {
                    Text("知道了").font(.system(size: 14, weight: .medium)).foregroundColor(T.primary)
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.stroke, lineWidth: 1))
            .padding(.horizontal, 40)
        }
    }

    // MARK: - 数据流

    private func loadRecent() {
        Task {
            if let d = try? await Network.post("v2/query/history", body: [
                "user_email": SessionStore.email, "page": 1, "page_size": 3,
            ]) {
                await MainActor.run { recentList = d["videos"].arr }
            }
        }
    }

    private func metricText(_ st: J, _ key: String) -> String? {
        let v = st[key]
        if !v.exists { return nil }
        if let d = v.dbl { return String(Int64(d)) }   // 完整数字不缩写
        if let s = v.str { return s.isEmpty ? nil : s }
        return nil
    }

    private func metricName(_ key: String) -> String? {
        MetricOrder.first { $0.key == key }?.label
    }

    private func resolution(_ r: J) -> String {
        guard let w = r["width"].int, let h = r["height"].int, w > 0, h > 0 else { return "" }
        return "\n分辨率：\(w)×\(h)"
    }

    private func timeText(_ raw: String) -> String {
        if let d = Fmt.time(raw) { return Fmt.full(d) }
        return raw
    }

    private func salesClues(_ v: Any) -> String {
        if let b = v as? Bool { return b ? "有" : "无" }
        if let n = v as? NSNumber { return n.intValue > 0 ? "\(n.intValue)条" : "无" }
        if let s = v as? String { return s }
        return "-"
    }

    private func parseHotWords(_ j: J) -> [String] {
        if let arr = j.raw as? [Any] { return arr.compactMap { ($0 as? String) ?? String(describing: $0) } }
        guard let s = j.str, !s.isEmpty else { return [] }
        if let data = s.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        return [s]
    }

    /// 值归一为行列表（字符串\n 拆行 / 数组逐项 / 对象逐值）
    private func normalizedLines(_ j: J) -> [String] {
        if let arr = j.raw as? [Any] {
            return arr.map { ($0 as? String) ?? String(describing: $0) }.filter { !$0.isEmpty }
        }
        if let d = j.raw as? [String: Any] {
            return d.values.map { ($0 as? String) ?? String(describing: $0) }.filter { !$0.isEmpty }
        }
        guard let s = j.str, !s.isEmpty else { return [] }
        return s.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    /// 雷达 5 维：率÷基准×50 限 [6,100]
    private func radarValues(_ st: J, _ play: Double) -> [Double] {
        func rate(_ k: String, _ base: Double) -> Double {
            guard let c = st[k].dbl else { return 6 }
            return min(100, max(6, (c / play) / base * 50))
        }
        return [rate("like_count", 0.03), rate("comment_count", 0.005), rate("share_count", 0.008),
                rate("collect_count", 0.008), rate("download_count", 0.001)]
    }

    private func radarLabels(_ st: J, _ play: Double) -> [String] {
        func pct(_ k: String) -> String {
            guard let c = st[k].dbl else { return "0%" }
            return String(format: "%.2f%%", c / play * 100)
        }
        return ["点赞 \(pct("like_count"))", "评论 \(pct("comment_count"))", "分享 \(pct("share_count"))",
                "收藏 \(pct("collect_count"))", "下载 \(pct("download_count"))"]
    }

    // MARK: - 主查询

    private func doQuery() {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请输入作品链接或ID"; return }
        let target = LinkParser.extractVideoTarget(raw)
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                var id = target.id
                if id == nil {
                    guard let url = target.url else { throw ApiError.business("无法识别作品ID，请检查链接") }
                    let pd = try await Network.post("query/parse-link", body: ["douyin_url": url])
                    id = pd["video_id"].str
                }
                guard let wid = id, !wid.isEmpty else {
                    throw ApiError.business("无法识别作品ID，请检查链接")
                }
                await MainActor.run { input = wid }
                let d = try await Network.post("v2/query/douyin", body: [
                    "works_ids": [wid],
                    "user_email": SessionStore.email,
                    "include_play": true,
                ])
                let r0 = d["results"][0]
                if !r0.exists {
                    throw ApiError.business(d["text"].str ?? "查询失败，请稍后重试")
                }
                await MainActor.run {
                    result = r0
                    resultTitle = r0["ai_title"].str ?? "\(r0["owner_nickname"].str ?? "未知作者") 的作品"
                    SessionStore.pushHistory(SessionStore.workHistoryKey, id: wid, name: r0["desc"].str ?? wid)
                    history = SessionStore.history(SessionStore.workHistoryKey)
                    bus.setBalance(d["new_balance"].dbl)
                }
            } catch let e as ApiError {
                await MainActor.run { self.error = e.errorDescription ?? "" }
            } catch {
                await MainActor.run { self.error = "查询失败，请稍后重试" }
            }
        }
    }

    /// 直通查询：先查数据再自动 AI（对齐 analyzeWorkById）
    private func analyzeWorkById(_ awemeId: String) {
        input = awemeId
        error = ""
        aiError = ""
        aiMsg = nil
        loading = true
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/douyin", body: [
                    "works_ids": [awemeId],
                    "user_email": SessionStore.email,
                    "include_play": true,
                ])
                let r0 = d["results"][0]
                guard r0.exists else { throw ApiError.business(d["text"].str ?? "查询失败") }
                await MainActor.run {
                    result = r0
                    resultTitle = r0["ai_title"].str ?? "\(r0["owner_nickname"].str ?? "未知作者") 的作品"
                    SessionStore.pushHistory(SessionStore.workHistoryKey, id: awemeId, name: r0["desc"].str ?? awemeId)
                    history = SessionStore.history(SessionStore.workHistoryKey)
                    bus.setBalance(d["new_balance"].dbl)
                }
                doAiAnalyze()
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "查询失败" }
            }
        }
    }

    // MARK: - AI 分析（5s × 60 轮询，连错 5 次放弃）

    private func doAiAnalyze() {
        guard let r = result else { return }
        guard let awemeId = r["aweme_id"].str, !awemeId.isEmpty else {
            aiError = "未找到作品ID，无法执行AI分析"
            return
        }
        guard !aiAnalyzing else { return }
        aiAnalyzing = true
        aiError = ""
        aiMsg = "AI 正在分析作品，请稍候（约 30-90 秒）..."
        Task {
            do {
                let d = try await Network.post("v2/query/ai/analyze", body: [
                    "aweme_id": awemeId,
                    "user_email": SessionStore.email,
                ])
                guard let taskId = d["task_id"].str, !taskId.isEmpty else {
                    throw ApiError.business("AI分析任务创建失败")
                }
                var failCnt = 0
                for _ in 0..<60 {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    do {
                        let rd = try await Network.get("v2/query/ai/analyze_result", query: ["task_id": taskId])
                        failCnt = 0
                        let status = rd["status"].str ?? ""
                        if status == "completed" {
                            await MainActor.run {
                                // 轮询结果含全部 8 AI 字段，暂存供展示（等价安卓深拷贝合并语义）
                                aiResultData = rd
                                aiMsg = nil
                                aiAnalyzing = false
                            }
                            return
                        }
                        if status == "failed" {
                            throw ApiError.business(rd["msg"].str ?? "AI分析失败")
                        }
                    } catch let e as ApiError {
                        throw e
                    } catch {
                        failCnt += 1
                        if failCnt >= 5 { throw ApiError.business("AI分析结果获取失败，请稍后重试") }
                    }
                }
                throw ApiError.business("AI分析超时，请稍后重试")
            } catch let e as ApiError {
                await MainActor.run { aiError = e.errorDescription ?? ""; aiMsg = nil; aiAnalyzing = false }
            } catch {
                await MainActor.run { aiError = "AI分析失败"; aiMsg = nil; aiAnalyzing = false }
            }
        }
    }

    /// AI 轮询结果暂存（结果区 8 字段展示优先取它，兼容原 JSON 深拷贝合并逻辑）
    @State private var aiResultData: J? = nil
}

/// 指标顺序（METRIC_ORDER 对齐）
let MetricOrder: [(key: String, label: String)] = [
    ("recommend_count", "播放/推荐量"),
    ("admire_count", "喜欢量"),
    ("like_count", "点赞量"),
    ("comment_count", "评论量"),
    ("share_count", "分享量"),
    ("collect_count", "收藏量"),
    ("download_count", "下载数"),
    ("view_count", "观看量"),
    ("play_count", "播放量"),
    ("play_index", "播放指数"),
]

/// 28 条标签释义（LABEL_TIPS 对齐）
let WorkTips: [String: String] = [
    "作品ID": "作品的唯一编号，可用于精确查询或分享定位该作品",
    "用户签名": "作者填写的个人简介，常带商务合作联系方式",
    "粉丝数": "作者账号的关注者数量，反映账号影响力与私域流量池",
    "总获赞数": "作者全部作品累计获得的点赞总数，反映历史内容质量",
    "认证类型": "账号认证性质：个人账号 / 企业号（蓝V），企业号有官方背书",
    "认证描述": "认证账号的资质说明或企业介绍",
    "播放/推荐量": "作品被推入流量池获得的曝光次数，判断流量池层级的核心指标",
    "喜欢量": "「长按点赞」的超级喜欢次数（权重高于普通点赞）",
    "点赞量": "用户双击点赞的总次数，衡量内容的即时吸引力",
    "评论量": "评论总数，反映互动深度与话题争议性",
    "分享量": "用户转发/分享的总次数，对流量推荐加权最重",
    "收藏量": "用户收藏作品的总次数，反映内容的实用/复看价值",
    "下载数": "作品被保存下载到本地的次数",
    "观看量": "直播等形态的观看人次，普通短视频通常为 0",
    "播放量": "作品实际播放次数，与推荐量对比可看转化效率",
    "播放指数": "平台综合播放表现折算的加权指数，非真实播放次数",
    "互动率": "各互动行为合计÷播放量，衡量内容的互动效率",
    "加权互动率": "互动行为按权重加权后÷播放量，更贴近算法评估视角",
    "查询时间": "本次（或最近一次）查询该作品数据的时间",
    "发布时间": "作品在抖音发布的具体时间",
    "是否带货": "作品是否挂载商品（购物车/小黄车）",
    "产品类型": "挂载商品的类型或带货形式",
    "销售线索": "作品带来的销售线索数量",
    "商品标题": "挂载商品的名称",
    "已售": "该商品的累计销量",
    "促销信息": "商品的促销活动说明（如限时折扣/赠品）",
    "查询状态": "本次查询是否成功获取作品数据",
    "限流": "作品是否被平台限制推荐，限流后曝光量会骤降",
]
