import SwiftUI

/// AI 账号权重分析页（对齐安卓 WeightScreen.kt）
struct WeightView: View {
    var onOpenHistory: () -> Void
    @ObservedObject private var bus = SessionBus.shared

    @State private var input = ""
    @State private var loading = false
    @State private var error = ""
    @State private var result: J? = nil
    @State private var sectionTip: (String, String)? = nil
    @State private var recentList: [J] = []
    @State private var history: [SessionStore.HistoryEntry] = []
    @State private var aiAnalyzing = false
    @State private var aiMsg: String? = nil
    @State private var aiError = ""
    @State private var aiResult: J? = nil
    @State private var showHelp = false
    @State private var snackbar = ""

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()
                    GradientBanner(title: "AI账号权重分析", subtitle: "支持短视频链接、直播间链接、主页链接、账号ID")

                    // 查询输入卡
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            QuotaRow()
                            TextField("粘贴APP分享的链接或输入账号", text: $input)
                                .font(.system(size: 14)).foregroundColor(T.textMain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                            HStack(spacing: 10) {
                                PrimaryButton(title: "立即查询", loading: loading) { doQuery() }
                                Button {
                                    paste()
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(T.primary).frame(width: 48, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                                }
                                .disabled(loading)
                                Button {
                                    withAnimation { showHelp.toggle() }
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(T.textSub).frame(width: 42, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                                }
                            }
                            if showHelp {
                                Text("① 复制APP分享的链接或输入账号ID\n② 点击「立即查询」开始分析\n③ 等待结果后可点击「AI 账号权重分析」获取深度建议\n\n支持：短视频链接 / 直播间链接 / 主页链接 / sec_uid / 账号ID")
                                    .font(.system(size: 12)).foregroundColor(T.textSub)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.06)))
                            }
                            ErrorText(text: error)
                        }
                    }

                    if result == nil {
                        recentSection
                        Button {
                            onOpenHistory()
                        } label: {
                            GlassCard(padding: 14) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath").foregroundColor(T.primary)
                                    Text("查询历史（与 Web 端同步）").font(.system(size: 14)).foregroundColor(T.textMain)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                                }
                            }
                        }
                    } else {
                        resultSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }

            if let tip = sectionTip { tipDialog(tip) }
        }
        .snackbar($snackbar)
        .onAppear {
            loadRecent()
            history = SessionStore.history(SessionStore.weightHistoryKey)
        }
        .onChange(of: bus.pendingWeightId) { id in
            // 历史 → 直查
            if let id = id {
                bus.pendingWeightId = nil
                input = id
                doQuery()
            }
        }
    }

    // MARK: - 最近查询（服务端前3条，失败回退本地 chips）

    @ViewBuilder
    private var recentSection: some View {
        if !recentList.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "最近查询")
                    ForEach(Array(recentList.enumerated()), id: \.offset) { _, r in
                        Button {
                            if let su = str(r, "sec_uid", "secUid"), !su.isEmpty {
                                input = su
                                doQuery()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                NetImage(url: str(r, "avatar_url", "avatarUrl"), size: 40).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(str(r, "nickname") ?? "未知昵称").font(.system(size: 14, weight: .medium)).foregroundColor(T.textMain)
                                    Text(str(r, "unique_id") ?? "").font(.system(size: 11)).foregroundColor(T.textSub)
                                }
                                Spacer()
                                Text((str(r, "last_query_time") ?? "").prefix(16)).font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                        }
                    }
                }
            }
        } else if !history.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "最近查询")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(history.prefix(5)) { h in
                                Button {
                                    input = h.id
                                    doQuery()
                                } label: {
                                    Text(String(h.id.prefix(18)))
                                        .font(.system(size: 12)).foregroundColor(T.primary)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(T.primary.opacity(0.10)))
                                        .overlay(Capsule().stroke(T.primary.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultSection: some View {
        let eff = effective(result!)
        let rows = eff["rowInfo"].arr

        // 头像信息卡
        GlassCard {
            HStack(spacing: 12) {
                NetImage(url: str(eff, "avatarUrl", "avatar_url"), size: 56).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(str(eff, "nickname") ?? "未知昵称").font(.system(size: 17, weight: .bold)).foregroundColor(T.textMain)
                    Text("账号：\(str(eff, "account") ?? "-")").font(.system(size: 12)).foregroundColor(T.textSub)
                    Text("查询时间：\(Fmt.mdhm(Date()))").font(.system(size: 12)).foregroundColor(T.textSub)
                }
                Spacer()
            }
        }

        // 核心指标 2×2
        SectionTitle(text: "核心指标")
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(["权重分", "活跃度", "健康度", "流量池"], id: \.self) { name in
                let v = rows.first { $0["rowName"].str == name }?["rowValue"].str ?? ""
                GlassCard(padding: 12) {
                    VStack(spacing: 6) {
                        Text(name).font(.system(size: 12)).foregroundColor(T.textSub)
                        Text(v.isEmpty ? "-" : v)
                            .font(.system(size: v.count > 8 ? 15 : 20, weight: .bold))
                            .foregroundColor(T.primary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }

        // AI 分析入口
        SectionTitle(text: "AI 账号权重分析")
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                PrimaryButton(title: aiAnalyzing ? "AI 分析中…" : "🔥 AI 账号权重分析",
                              loading: aiAnalyzing, enabled: !aiAnalyzing) { startAI() }
                if let m = aiMsg { Text(m).font(.system(size: 12)).foregroundColor(T.textSub) }
                if !aiError.isEmpty { Text(aiError).font(.system(size: 12)).foregroundColor(Color(hex: "FB7185")) }
                if aiResult == nil && !aiAnalyzing {
                    Text("AI 将结合权重数据深度分析账号，生成涨粉策略/内容策略/风险预警/30天计划（约 30-90 秒）")
                        .font(.system(size: 12)).foregroundColor(T.textSub)
                }
                if let ai = aiResult {
                    ForEach(Array(AIWeightSections.enumerated()), id: \.offset) { _, sec in
                        let body = ai[sec.key].str ?? ""
                        if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(sec.title).font(.system(size: 14, weight: .semibold)).foregroundColor(T.primary)
                                    Button { sectionTip = (sec.title, AIWeightSectionTips[sec.key] ?? "") } label: {
                                        Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundColor(T.textSub)
                                    }
                                }
                                Text(body).font(.system(size: 13)).foregroundColor(T.textMain)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                        }
                    }
                }
            }
        }

        // 权重指标普通行
        SectionTitle(text: "权重指标")
        GlassCard {
            VStack(spacing: 2) {
                let coverRows = rows.filter { $0["isShow"].bool && $0["rowValueType"].int == 1 && !$0["rowValueDetail"].arr.isEmpty }
                ForEach(Array(rows.filter { $0["isShow"].bool && !($0["rowValueType"].int == 1 && !$0["rowValueDetail"].arr.isEmpty) }.enumerated()),
                        id: \.offset) { _, row in
                    WeightRowView(row: row, onTapTip: { sectionTip = $0 }, onWork: { awemeId in
                        bus.pendingWorkId = awemeId
                        snackbar = "已切换到作品分析页"
                    })
                    Divider().overlay(Color.white.opacity(0.05))
                }
                ForEach(Array(coverRows.enumerated()), id: \.offset) { _, row in
                    CoverGridRow(row: row, onWork: { awemeId in
                        bus.pendingWorkId = awemeId
                        snackbar = "已切换到作品分析页"
                    })
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func tipDialog(_ tip: (String, String)) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { sectionTip = nil }
            VStack(alignment: .leading, spacing: 12) {
                Text(tip.0).font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)
                ScrollView(showsIndicators: false) {
                    Text(tip.1).font(.system(size: 13)).foregroundColor(T.textSub)
                }
                .frame(maxHeight: 200)
                Button {
                    sectionTip = nil
                } label: {
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

    // MARK: - 数据

    private func loadRecent() {
        Task {
            do {
                let d = try await Network.post("v2/query/weight/history", body: [
                    "user_email": SessionStore.email, "page": 1, "page_size": 3,
                ])
                await MainActor.run { recentList = d["list"].arr }
            } catch { }
        }
    }

    /// effective 兼容：weight_info.data.rowInfo != null ? weight_info.data : 原始
    private func effective(_ d: J) -> J {
        let inner = d["weight_info"]["data"]
        if !inner["rowInfo"].arr.isEmpty || inner["rowInfo"].exists { return inner }
        return d
    }

    private func doQuery() {
        let inp = LinkParser.extractUserInput(input)
        guard !inp.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "请输入链接、账号或ID"
            return
        }
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/weight", body: [
                    "user_email": SessionStore.email,
                    "input": inp,
                ])
                let eff = effective(d)
                guard !eff["rowInfo"].arr.isEmpty || eff["rowInfo"].exists else {
                    await MainActor.run { error = "查询失败，请稍后重试" }
                    return
                }
                await MainActor.run {
                    result = d
                    aiResult = nil
                    aiError = ""
                    aiMsg = nil
                    SessionStore.pushHistory(SessionStore.weightHistoryKey, id: inp, name: str(eff, "nickname") ?? inp)
                    history = SessionStore.history(SessionStore.weightHistoryKey)
                    bus.setBalance(d["new_balance"].dbl)
                    bus.setUsage(consume: d["consume_today"].int, used: nil, limit: nil)
                }
            } catch let e as ApiError {
                await MainActor.run { self.error = e.errorDescription ?? "" }
            } catch {
                await MainActor.run { self.error = "查询失败，请稍后重试" }
            }
        }
    }

    private func paste() {
        if let s = UIPasteboard.general.string, !s.trimmingCharacters(in: .whitespaces).isEmpty {
            input = s.trimmingCharacters(in: .whitespaces)
            snackbar = "已粘贴，点击「立即查询」开始"
        } else {
            snackbar = "剪贴板是空的，先去复制分享链接吧"
        }
    }

    // MARK: - AI 分析（提交 + 60×5s 轮询）

    private func startAI() {
        guard let r = result else { return }
        let eff = effective(r)
        let rows = eff["rowInfo"].arr
        func rowVal(_ name: String) -> String {
            rows.first { $0["rowName"].str == name }?["rowValue"].str ?? "未知"
        }
        let weightData: [String: Any] = [
            "secUserId": str(eff, "secUserId", "sec_uid") ?? "",
            "nickname": str(eff, "nickname") ?? "",
            "account": str(eff, "account") ?? "",
            "desc": str(eff, "desc") ?? "",
            "avatarUrl": str(eff, "avatarUrl", "avatar_url") ?? "",
            "weightScore": rowVal("权重分"),
            "activity": rowVal("活跃度"),
            "dataIntegrity": rowVal("资料完整度"),
            "health": rowVal("健康度"),
            "rowInfo": rows.map(\.raw),
        ]
        aiAnalyzing = true
        aiError = ""
        aiMsg = "AI 正在深度分析账号权重，请耐心等待（约 30-90 秒）..."
        Task {
            do {
                let d = try await Network.post("v2/query/ai/analyze_weight", body: [
                    "weight_data": weightData,
                    "user_email": SessionStore.email,
                ])
                guard let taskId = d["task_id"].str, !taskId.isEmpty else {
                    throw ApiError.business(d["msg"].str ?? "AI权重分析任务创建失败")
                }
                // 轮询 60 次 × 5s，连续 5 次网络错误放弃
                var failCnt = 0
                for _ in 0..<60 {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    do {
                        let rd = try await Network.get("v2/query/ai/analyze_result", query: ["task_id": taskId])
                        failCnt = 0
                        let status = rd["status"].str ?? ""
                        if status == "completed" {
                            await MainActor.run { aiResult = rd; aiMsg = nil; aiAnalyzing = false }
                            return
                        }
                        if status == "failed" {
                            throw ApiError.business(rd["msg"].str ?? "AI权重分析失败")
                        }
                    } catch let e as ApiError {
                        throw e
                    } catch {
                        failCnt += 1
                        if failCnt >= 5 { throw ApiError.business("AI分析结果获取失败，请稍后重试") }
                    }
                }
                throw ApiError.business("AI权重分析超时，请稍后重试")
            } catch let e as ApiError {
                await MainActor.run { aiError = e.errorDescription ?? ""; aiMsg = nil; aiAnalyzing = false }
            } catch {
                await MainActor.run { aiError = "AI权重分析失败"; aiMsg = nil; aiAnalyzing = false }
            }
        }
    }
}

// MARK: - 常量表

enum WeightConst {
    /// AI 5 区块（key→标题）
    static let AIWeightSections: [(key: String, title: String)] = [
        ("weight_analysis", "📊 权重综合诊断"),
        ("growth_suggestions", "📈 涨粉与成长策略"),
        ("content_strategy", "🎨 内容策略分析"),
        ("risk_assessment", "⚠️ 风险预警与合规建议"),
        ("optimization_plan", "🗓️ 30天优化执行计划"),
    ]

    static let AIWeightSectionTips: [String: String] = [
        "weight_analysis": "解读账号当前权重分、等级和流量池层级，告诉你账号在平台推荐算法中的位置与整体状况。",
        "growth_suggestions": "结合粉丝画像与活跃表现，分析账号当前的成长瓶颈，给出涨粉路径与运营节奏建议。",
        "content_strategy": "分析账号内容垂直度、选题方向与发布习惯，指导做什么类型的内容更容易获得平台推荐。",
        "risk_assessment": "排查账号潜在的违规风险与限流隐患，提前规避降权、封禁等问题，保持账号健康。",
        "optimization_plan": "把前面的分析结论拆解成按周推进的 30 天行动清单，照着执行即可逐步提升账号权重。",
    ]

    /// 图标型字段（网络图 RATING_BASE + rowValue）
    static let imageFields: Set<String> = [
        "达人等级", "带货评分", "账号评级", "作品评级", "直播评级", "信用评级",
        "内容质量", "活跃评级", "涨粉能力", "商业化能力", "健康评级", "原创评级",
    ]

    static let ratingBase = "https://doushujun.me/img/rating/"

    /// 字段提示（WEIGHT_FIELD_TIPS 全量迁移）
    static let fieldTips: [String: String] = [
        "权重分": "账号在平台推荐体系中的综合量化评分，分数越高越容易进入更高层级流量池，获得更多推荐曝光",
        "活跃度": "综合发布频率、互动行为等评估的账号活跃程度，保持稳定更新有助于活跃度提升",
        "资料完整度": "头像、昵称、简介、背景图、认证等账号资料的完善程度，资料越完整对权重评估越有利",
        "健康度": "账号内容合规与行为健康状态，搬运、违规营销等行为会拉低健康度",
        "投稿数": "账号累计发布的作品总量",
        "近7天投稿数": "最近 7 天发布的作品数量，反映当前更新频率，建议保持稳定更新节奏",
        "话题": "作品挂载的话题标签，参与热门或垂类话题有助于进入话题流量池",
        "流量池": "当前作品所处的推荐流量层级，平台按层级逐级放大推荐",
        "综合评级": "对账号权重、内容、商业化等维度的综合等级评价（A/B/C/D）",
        "权重等级": "账号在平台推荐体系中的权重等级（1-9 级，等级越高推荐权重越大）",
        "账号评级": "平台对账号整体质量的评级",
        "作品评级": "近期作品质量的评级",
        "直播评级": "直播内容与直播数据表现的评级",
        "信用评级": "账号合规信用评级，违规行为会降低",
        "内容质量": "从原创性、完播率等维度评估的内容质量水平",
        "活跃评级": "账号活跃程度的评级",
        "涨粉能力": "近期粉丝增长速度与潜力的评级",
        "商业化能力": "账号带货、广告等商业变现能力的评级",
        "健康评级": "账号健康状态的评级",
        "原创评级": "内容原创程度的评级",
        "达人等级": "电商达人等级，等级越高带货权限与流量扶持越多",
        "带货评分": "带货能力的综合评分",
        "账号标签": "平台给账号打的内容垂类标签，决定作品被推荐给哪类人群",
        "认证信息": "账号的官方认证状态（个人/企业/机构认证）",
        "简介": "账号个人简介内容",
        "总获赞量": "账号全部作品累计获得的点赞总数",
        "总关注量": "账号关注的其他用户总数",
        "总粉丝量": "账号当前粉丝总数",
        "学校": "账号资料中填写的学校信息",
        "年龄": "账号资料中的年龄信息",
        "地域": "账号资料或 IP 归属地展示的地区",
        "性别": "账号资料中的性别信息",
        "账号估价，仅供参考": "根据粉丝量与数据表现估算的账号商业价值，仅供参考",
        "是否同步头条": "作品是否开启同步至今日头条",
        "粉丝活跃时间": "粉丝最活跃的时间段，可作为发布时间参考",
        "赞粉比": "累计获赞与粉丝数之比，比值越高说明内容质量与传播力越强",
    ]
}

/// camelCase/snake_case 双兼容取字符串
func str(_ j: J, _ k1: String, _ k2: String? = nil) -> String? {
    let v = j[k1].str
    if let v = v, !v.isEmpty { return v }
    if let k2 = k2, let v2 = j[k2].str, !v2.isEmpty { return v2 }
    return v ?? j[k2 ?? k1].str
}

// MARK: - 权重行渲染（图标三分支 + 建议着色）

struct WeightRowView: View {
    let row: J
    var onTapTip: ((String, String)) -> Void
    var onWork: (String) -> Void

    var body: some View {
        let name = row["rowName"].str ?? ""
        let value = row["rowValue"].str ?? ""
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 4) {
                Text(name).font(.system(size: 14)).foregroundColor(T.textSub)
                if let tip = WeightConst.fieldTips[name] {
                    Button { onTapTip((name, tip)) } label: {
                        Image(systemName: "questionmark.circle").font(.system(size: 11)).foregroundColor(T.textSub.opacity(0.7))
                    }
                }
            }
            Spacer()
            valueView(name: name, value: value)
            if let desc = row["rowDesc"].str, !desc.isEmpty {
                Text(desc.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(descColor)
                    .lineLimit(1)
                    .frame(maxWidth: 96, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }

    private var descColor: Color {
        if let code = row["rowDescColorCode"].str {
            let hex = code.replacingOccurrences(of: "#", with: "")
            if hex.count == 6 { return Color(hex: hex) }
        }
        return T.textSub
    }

    @ViewBuilder
    private func valueView(name: String, value: String) -> some View {
        if WeightConst.imageFields.contains(name) && !value.isEmpty {
            // 图标型字段：网络评级图
            AsyncImage(url: URL(string: WeightConst.ratingBase + value)) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
            }
            .frame(height: 28)
        } else if name == "权重等级", value.hasPrefix("/img/dengji/") {
            // 权重等级：本地 dengji_N 徽章
            let n = value.components(separatedBy: "/").last?
                .replacingOccurrences(of: "dengji_", with: "")
                .replacingOccurrences(of: ".png", with: "") ?? ""
            if let img = UIImage(named: "dengji_\(n)") {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 28)
            } else {
                Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
            }
        } else if name == "综合评级", value.hasPrefix("/img/rating/") {
            // 综合评级：后端值如 "/img/rating/C级.png" → 取末段 "C级.png" → 去 ".png"/去「级」 → "c"
            // → 本地 asset rating_a/b/c/d 显示徽章图（对齐安卓 rating_a drawable；原图缺失时回退文本）
            let letter = (value.components(separatedBy: "/").last ?? "")     // "C级.png"
                .replacingOccurrences(of: ".png", with: "")                  // → "C级"
                .replacingOccurrences(of: "级", with: "")                    // → "C"
                .lowercased()                                                // → "c"（asset 命名小写）
            if let img = UIImage(named: "rating_\(letter)") {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 30)
            } else {
                Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
            }
        } else {
            Text(value.isEmpty ? "无" : value)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// 封面网格行（rowValueType==1）：行名+rowDesc → 两列封面卡（含统计数据）
struct CoverGridRow: View {
    let row: J
    var onWork: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row["rowName"].str ?? "").font(.system(size: 14)).foregroundColor(T.textSub)
                Spacer()
                if let d = row["rowDesc"].str, !d.isEmpty {
                    Text(d).font(.system(size: 11)).foregroundColor(T.textSub)
                }
            }
            let items = Array(row["rowValueDetail"].arr.enumerated())
            let chunks = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<Swift.min($0 + 2, items.count)]) }
            ForEach(chunks, id: \.first?.offset) { chunk in
                HStack(spacing: 10) {
                    ForEach(chunk, id: \.offset) { _, it in
                        CoverCell(item: it, onWork: onWork)
                    }
                    if chunk.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }
}

private struct CoverCell: View {
    let item: J
    var onWork: (String) -> Void

    private var src: String {
        let s = item["src"].str ?? ""
        if s.hasPrefix("http") { return s }
        return WeightConst.ratingBase + s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NetImage(url: src, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(item["name"].str ?? "").font(.system(size: 12)).foregroundColor(T.textMain).lineLimit(1)
            let st = stats
            HStack(spacing: 8) {
                Label(num(st["play_count"]), systemImage: "play").foregroundColor(T.textSub)
                Label(num(st["digg_count"]), systemImage: "hand.thumbsup").foregroundColor(T.textSub)
                Label(num(st["comment_count"]), systemImage: "bubble.right").foregroundColor(T.textSub)
            }
            .font(.system(size: 10))
            if let id = item["aweme_id"].str, !id.isEmpty {
                Button {
                    onWork(id)
                } label: {
                    Text("AI作品分析").font(.system(size: 10, weight: .medium)).foregroundColor(T.primary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(T.primary.opacity(0.12)))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        .frame(maxWidth: .infinity)
    }

    /// tips → video_stats[0].statistics
    private var stats: [String: Double] {
        guard let raw = item["tips"].str,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        let vs = J(obj)["video_stats"][0]["statistics"].dict
        var out: [String: Double] = [:]
        for (k, v) in vs { out[k] = v.dbl ?? 0 }
        return out
    }

    private func num(_ v: Double?) -> String {
        guard let v = v else { return "0" }
        let a = abs(v)
        if a >= 1e8 { return String(format: "%.1f亿", v / 1e8) }
        if a >= 1e4 { return String(format: "%.1f万", v / 1e4) }
        return String(Int64(v))
    }
}

/// AI_WEIGHT_SECTIONS 便捷访问
private let AIWeightSections = WeightConst.AIWeightSections.map { (key: $0.key, title: $0.title) }
private let AIWeightSectionTips = WeightConst.AIWeightSectionTips
