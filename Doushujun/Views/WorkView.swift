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
    @AppStorage("work_history_style") private var recStyle = "list"   // 查询记录视图样式（持久化，下次进入保持）
    @State private var recQuery = ""                                  // 查询记录搜索词

    var body: some View {
        ZStack {
            TechBackground()                       // 科技感背景层
            ScrollView(showsIndicators: false) {   // 纵向主滚动
                VStack(spacing: 14) {
                    AnnouncementBar()              // 公告栏
                    GradientBanner(title: "AI作品优化分析", subtitle: "播放量、点赞评论等全维度数据 + AI 优化建议")  // 渐变横幅

                    // 查询输入卡
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            QuotaRow()             // 今日余量提示行
                            TextField("粘贴作品分享链接或19位ID", text: $input)   // 链接输入框
                                .font(.system(size: 14)).foregroundColor(T.textMain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                            HStack(spacing: 10) {
                                PrimaryButton(title: "立即分析", loading: loading) { doQuery() }   // 主查询按钮
                                Button { paste() } label: {           // 粘贴按钮（对齐权重分析页）
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(T.primary).frame(width: 48, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                                }
                                .disabled(loading)
                                Button { onOpenHistory() } label: {   // 历史入口按钮
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(T.primary).frame(width: 48, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                                }
                                Button { withAnimation { showHelp.toggle() } } label: {   // 帮助展开按钮
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(T.textSub).frame(width: 42, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                                }
                            }
                            Text("✨ 支持AI作品分析")     // 能力标签
                                .font(.system(size: 11, weight: .medium)).foregroundColor(T.primary)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(T.primary.opacity(0.12)))
                                .frame(maxWidth: .infinity)
                            if showHelp {          // 展开的帮助文案
                                Text("① 复制APP分享的作品链接或输入19位作品ID\n② 点击「立即分析」开始查询\n③ 查询完成后点击「AI作品分析」获取优化建议\n\n数据为发布以来累计值，建议先看播放/推荐量判断流量池层级")
                                    .font(.system(size: 12)).foregroundColor(T.textSub)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.06)))
                            }
                            ErrorText(text: error) // 错误提示行
                        }
                    }

                    // 未查询→最近分析；已查询→结果区
                    if result == nil {
                        recentSection
                    } else {
                        resultSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            if let t = tip { tipDialog(t) }        // 释义弹窗覆盖层
        }
        .snackbar($snackbar)
        .onAppear {
            history = SessionStore.history(SessionStore.workHistoryKey)   // 刷新本地足迹
            loadRecent()                           // 拉服务端最近分析
            bus.refreshAccount()                   // 进入页面即拉配额：打开界面立即显示今日已用/剩余
        }
        .onChange(of: bus.pendingWorkId) { id in
            // 直通车：历史/权重页封面 → 直查并自动 AI
            if let id = id {
                bus.pendingWorkId = nil            // 消费信号防重复触发
                input = id
                analyzeWorkById(id)
            }
        }
    }

    // MARK: - 查询记录（服务端前 10，四种视图样式 + 搜索，对齐安卓 WorkScreen.kt）

    /// 查询记录区：标题行（条数徽章+云同步徽章）+ 样式切换 + 搜索框 + 记录视图
    @ViewBuilder
    private var recentSection: some View {
        if !recentList.isEmpty {
            // 标题行：渐变竖条 + 条数徽章（搜索时显示匹配数）+ 云同步徽章
            HStack(spacing: 6) {
                SectionTitle(text: "查询记录")
                Text(recQuery.isEmpty ? "共 \(recentList.count) 条" : "匹配 \(filteredRecs.count)/\(recentList.count) 条")
                    .font(.system(size: 10)).foregroundColor(T.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(T.primary.opacity(0.12)))
                Spacer()
                Text("☁ 与 Web 端同步")
                    .font(.system(size: 10)).foregroundColor(T.primary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(T.primary.opacity(0.12)))
            }
            // 四种视图切换器：选中主题色胶囊，样式 @AppStorage 持久化
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([("list", "列表"), ("card", "卡片列表"), ("grid", "仪表网格"), ("timeline", "时间线")], id: \.0) { pair in
                        Button { recStyle = pair.0 } label: {
                            Text(pair.1)
                                .font(.system(size: 11, weight: recStyle == pair.0 ? .semibold : .regular))
                                .foregroundColor(recStyle == pair.0 ? .white : T.textSub)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(recStyle == pair.0 ? T.primary : T.primary.opacity(0.08)))
                        }
                    }
                }
            }
            // 搜索框：描述 / 作品ID / 账号 / 时间
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(T.textSub)
                TextField("搜索记录：描述 / 作品ID / 账号 / 时间", text: $recQuery)
                    .font(.system(size: 13)).foregroundColor(T.textMain).autocorrectionDisabled()
                if !recQuery.isEmpty {
                    Button { recQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(T.textSub)
                    }
                }
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
            // 记录视图
            if filteredRecs.isEmpty {
                Text("未找到匹配的记录").font(.system(size: 12)).foregroundColor(T.textSub)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                switch recStyle {
                case "card": recCards
                case "grid": recGrid
                case "timeline": recTimeline
                default: recList
                }
            }
        } else if !history.isEmpty {           // 本地 chips 回退
            SectionTitle(text: "最近分析")
            GlassCard {
                HStack(spacing: 8) {
                    ForEach(history.prefix(3)) { h in
                        Button {
                            input = h.id          // 点 chip 回填查询
                            doQuery()
                        } label: {
                            Text(String(h.id.prefix(18)))   // ID 截前 18 字
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
        Button { onOpenHistory() } label: {    // 固定历史入口卡
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

    // MARK: - 查询记录视图（列表/卡片/网格/时间线）

    /// 搜索过滤：描述/作品ID/作者昵称/作者账号/查询时间任一命中即保留
    private var filteredRecs: [J] {
        guard !recQuery.isEmpty else { return recentList }
        let q = recQuery.lowercased()
        return recentList.filter { r in
            [r["desc"].str, r["aweme_id"].str, r["owner_nickname"].str, r["owner_handle"].str, r["last_query_time"].str]
                .contains { ($0 ?? "").lowercased().contains(q) }
        }
    }

    /// 列表（默认）：紧凑行卡（竖版封面缩略），一屏条数最多
    private var recList: some View {
        VStack(spacing: 8) {
            ForEach(Array(filteredRecs.enumerated()), id: \.offset) { _, r in
                recTap(r) {
                    GlassCard(padding: 12) {
                        HStack(spacing: 12) {
                            NetImage(url: recCover(r), width: 56, height: 74)   // 竖版封面缩略
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recDesc(r))
                                    .font(.system(size: 13, weight: .medium)).foregroundColor(T.textMain).lineLimit(2)
                                Text("账号：\(r["owner_handle"].str ?? r["author_unique_id"].str ?? "-")")   // 作者双字段
                                    .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                Text("查询时间：\(recTime(r))")
                                    .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    /// 卡片列表：全宽封面大卡，信息最完整
    private var recCards: some View {
        VStack(spacing: 8) {
            ForEach(Array(filteredRecs.enumerated()), id: \.offset) { _, r in
                recTap(r) {
                    GlassCard(padding: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            NetImage(url: recCover(r), height: 150)   // 全宽 16:9 封面
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(recDesc(r))
                                .font(.system(size: 13, weight: .medium)).foregroundColor(T.textMain).lineLimit(3)
                            Text("账号：\(r["owner_handle"].str ?? r["author_unique_id"].str ?? "-")")
                                .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                            Text("查询时间：\(recTime(r))")
                                .font(.system(size: 11)).foregroundColor(T.textSub)
                        }
                    }
                }
            }
        }
    }

    /// 仪表网格：双列 1:1 封面，横向扫读对比
    private var recGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(filteredRecs.enumerated()), id: \.offset) { _, r in
                recTap(r) {
                    GlassCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            NetImage(url: recCover(r), height: 120)   // 1:1 封面（网格列宽自适应）
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(recDesc(r))
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(T.textMain).lineLimit(2)
                            Text("查询时间：\(recTime(r))")
                                .font(.system(size: 10)).foregroundColor(T.textSub).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    /// 时间线：左侧发光轴+主题色节点，右侧记录卡（回溯最直观）
    private var recTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredRecs.enumerated()), id: \.offset) { i, r in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle().fill(T.primary).frame(width: 9, height: 9)   // 发光节点
                        if i < filteredRecs.count - 1 {
                            Rectangle().fill(T.primary.opacity(0.25)).frame(width: 2).frame(maxHeight: .infinity)   // 轴线撑满到下一条
                        }
                    }
                    recTap(r) {
                        GlassCard(padding: 12) {
                            HStack(spacing: 10) {
                                NetImage(url: recCover(r), width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(recDesc(r))
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(T.textMain).lineLimit(1)
                                    Text("账号：\(r["owner_handle"].str ?? r["author_unique_id"].str ?? "-")")
                                        .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                    Text("查询时间：\(recTime(r))")
                                        .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    /// 记录卡统一点击行为：回填作品 ID 并发起查询
    private func recTap<R: View>(_ r: J, @ViewBuilder label: () -> R) -> some View {
        Button {
            if let id = r["aweme_id"].str {
                input = id
                doQuery()
            }
        } label: { label() }
    }

    /// 封面双字段兼容
    private func recCover(_ r: J) -> String? {
        r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str
    }

    /// 描述缺省兜底
    private func recDesc(_ r: J) -> String {
        let d = r["desc"].str ?? ""
        return d.isEmpty ? "未命名作品" : d
    }

    /// 查询时间截 16 位可读化
    private func recTime(_ r: J) -> String {
        String((r["last_query_time"].str ?? "").prefix(16))
    }

    // MARK: - 结果区

    /// 结果区：作品信息/作者信息/数据表现/雷达图/时间/带货/热搜词/状态/AI 入口/建议
    @ViewBuilder
    private var resultSection: some View {
        let r = result!

        // 清空查询结果：回查询记录区（对齐安卓 WorkScreen.kt）
        HStack {
            Spacer()
            Button {
                result = nil
                aiResultData = nil
                snackbar = "已清空查询结果"
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle").font(.system(size: 12))
                    Text("清空查询结果").font(.system(size: 12))
                }
                .foregroundColor(T.textSub)
            }
        }

        // 作品信息
        SectionTitle(text: "作品信息")
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    NetImage(url: r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str, width: 86, height: 114)   // 大封面（双字段兼容）
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 6) {
                        Text({ let d = r["desc"].str ?? ""; return d.isEmpty ? "无描述" : d }())   // 描述（3 行截断，长按复制）
                            .font(.system(size: 13)).foregroundColor(T.textMain).lineLimit(3)
                            .copyable(r["desc"].str)
                        Text("分类：\(r["video_category_desc"].str ?? "无")\n形式：\(r["orientation"].str ?? "未知")    时长：\(r["duration_formatted"].str ?? "未知")\(resolution(r))")   // 元信息+分辨率，长按复制
                            .font(.system(size: 11)).foregroundColor(T.textSub)
                            .copyable("分类：\(r["video_category_desc"].str ?? "无")\n形式：\(r["orientation"].str ?? "未知")    时长：\(r["duration_formatted"].str ?? "未知")\(resolution(r))")
                        if let tp = r["traffic_pool_desc"].str, !tp.isEmpty {   // 流量池（有值才显示，长按复制）
                            Text("流量池：\(tp)").font(.system(size: 11)).foregroundColor(T.warn)
                                .copyable("流量池：\(tp)")
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let aiTitle = r["ai_title"].str, !aiTitle.isEmpty {   // AI 推荐标题（| 转行，长按复制）
                    Text("AI 推荐标题").font(.system(size: 11)).foregroundColor(T.textSub)
                    Text(aiTitle.replacingOccurrences(of: "|", with: "\n"))
                        .font(.system(size: 13)).foregroundColor(T.warn)
                        .copyable(aiTitle.replacingOccurrences(of: "|", with: "\n"))
                }
                infoLine("作品ID", r["aweme_id"].str ?? "")
            }
        }

        // 作者信息（根级字段优先，author_info 兜底）
        let author = r["author_info"]
        let aField: (String) -> String = { k in    // 双来源取值闭包
            let v = r[k].str
            if let v = v, !v.isEmpty { return v }
            return author[k].str ?? ""
        }
        SectionTitle(text: "作者信息")
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(aField("owner_nickname"))  @\(aField("owner_handle"))")   // 昵称 @handle，长按复制
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
                    .copyable("\(aField("owner_nickname"))  @\(aField("owner_handle"))")
                infoLine("用户签名", aField("signature"))
                infoLine("粉丝数", aField("follower_count"))
                infoLine("总获赞数", aField("total_favorited"))
                infoLine("认证类型", { let v = aField("verification_type_desc"); return v.isEmpty ? "未认证" : v }())   // 缺省"未认证"
                if let vd = (r["verification_desc"].str ?? author["verification_desc"].str), !vd.isEmpty {   // 认证描述双来源
                    infoLine("认证描述", vd)
                } else if let ev = (r["enterprise_verify_reason"].str ?? author["enterprise_verify_reason"].str), !ev.isEmpty {   // 企业认证兜底
                    infoLine("认证描述", ev)
                }
            }
        }

        // 数据表现（stats 子对象或根级，按固定顺序渲染）
        let st = r["stats"].exists ? r["stats"] : r
        SectionTitle(text: "数据表现")
        GlassCard {
            VStack(spacing: 2) {
                ForEach(MetricOrder, id: \.key) { m in
                    if let v = metricText(st, m.key) {   // 有值才渲染该行（长按复制）
                        HStack {
                            tipIcon("播放/推荐量" == m.label || metricName(m.key) != nil, m.label)   // 可释义行带问号
                            Text(m.label).font(.system(size: 13)).foregroundColor(T.textSub)
                            Spacer()
                            Text(v).font(.system(size: 13)).foregroundColor(T.textMain)
                                .copyable(v)             // 长按复制数值
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let er = r["engagement_rate_formatted"].str, !er.isEmpty {   // 互动率行（长按复制）
                    HStack {
                        tipIcon(true, "互动率")
                        Text("互动率").font(.system(size: 13)).foregroundColor(T.textSub)
                        Spacer()
                        Text(er).font(.system(size: 13)).foregroundColor(T.primary)
                            .copyable(er)
                    }
                    .padding(.vertical, 4)
                }
                let wr = r["weighted_engagement_rate_formatted"].str   // 加权互动率（格式化字段或数值拼 %，长按复制）
                    ?? r["weighted_engagement_rate"].dbl.map { String(format: "%.2f%%", $0) }
                if let wr = wr, !wr.isEmpty {
                    HStack {
                        tipIcon(true, "加权互动率")
                        Text("加权互动率").font(.system(size: 13)).foregroundColor(T.textSub)
                        Spacer()
                        Text(wr).font(.system(size: 13)).foregroundColor(T.primary)
                            .copyable(wr)
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        // 互动率画像雷达图（有播放量才画）
        if let play = st["play_count"].dbl ?? st["recommend_count"].dbl, play > 0 {
            SectionTitle(text: "互动率画像")
            GlassCard {
                VStack(spacing: 8) {
                    RadarChartView(
                        values: radarValues(st, play),    // 五维归一值
                        labels: radarLabels(st, play)     // 各维占比标签
                    )
                    Text("顶点为实际互动率 ÷ 行业参考基准：中圈=基准，外圈=2倍基准（封顶）")   // 图例说明
                        .font(.system(size: 10)).foregroundColor(T.textSub)
                }
            }
        }

        // 时间信息（查询/发布时间有任一才显示）
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

        // 带货信息（带货视频才显示）
        let isProduct = r["is_product_video"].bool
        if isProduct {
            SectionTitle(text: "带货信息")
            GlassCard {
                VStack(spacing: 4) {
                    infoLine("是否带货", "是")
                    if let pd = r["product_details"].raw as? [String: Any] {   // 商品详情字典
                        let p = J(pd)
                        if let v = p["product_type"].str { infoLine("产品类型", v) }
                        if let sc = p["sales_clues"].raw as Any? {   // 销售线索多形态
                            infoLine("销售线索", salesClues(sc))
                        }
                        if let v = p["product_info"]["title"].str { infoLine("商品标题", v) }
                        if let v = p["product_info"]["sales"].int { infoLine("已售", String(v)) }
                        let promos = p["promotional_info"].arr.compactMap(\.str)   // 促销列表顿号拼接
                        if !promos.isEmpty { infoLine("促销信息", promos.joined(separator: "、")) }
                    }
                }
            }
        }

        // 热搜词（数组/JSON字符串/纯文本三态解析）
        let hotWords = parseHotWords(r["hot_words"])
        if !hotWords.isEmpty {
            SectionTitle(text: "热搜词")
            GlassCard {
                Text(hotWords.joined(separator: "、")).font(.system(size: 13)).foregroundColor(T.textMain)   // 顿号拼接
            }
        }

        // 作品状态（含限流与原因）
        SectionTitle(text: "作品状态")
        GlassCard {
            VStack(spacing: 4) {
                infoLine("查询状态", (r["status"].str ?? "") == "error" ? "✗ 失败" : "✓ 成功")   // 状态勾叉
                let limited = r["is_limited"].bool
                infoLine("限流", limited ? "⚠ 已限流" : "正常", color: limited ? T.danger : .green)   // 限流红/绿
                if limited, let reason = r["limit_reason"].str, !reason.isEmpty {   // 限流原因
                    Text("限流原因：\(reason)").font(.system(size: 12)).foregroundColor(Color(hex: "FB7185"))
                }
            }
        }

        // AI 作品分析入口
        SectionTitle(text: "AI 作品分析")
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                PrimaryButton(title: aiAnalyzing ? "分析中…" : "AI作品分析",
                              loading: aiAnalyzing, enabled: !aiAnalyzing) { doAiAnalyze() }   // 分析中禁点
                if let m = aiMsg { Text(m).font(.system(size: 12)).foregroundColor(T.textSub) }   // 过程提示
                if !aiError.isEmpty { Text(aiError).font(.system(size: 12)).foregroundColor(Color(hex: "FB7185")) }   // 错误行
            }
        }

        // AI 优化建议（8 字段）
        aiSectionsView(r)
    }

    /// AI 建议区：7 字段区块逐项渲染（无任何内容整块隐藏）
    @ViewBuilder
    private func aiSectionsView(_ r: J) -> some View {
        // AI 字段优先取轮询结果（aiResultData），无则回退查询结果
        let aiData = aiResultData?.exists == true ? aiResultData! : r
        let fields: [(String, String)] = [     // (字段名, 展示标题) 顺序即渲染顺序
            ("optimization_tips", "💡 优化建议"),
            ("content_evaluation", "📋 内容质量评分"),
            ("data_analysis", "📊 数据表现分析"),
            ("optimization_directions", "🎯 优化方向"),
            ("hashtag_suggestions", "#️⃣ 推荐话题标签"),
            ("posting_time_advice", "⏰ 发布时间建议"),
            ("competition_analysis", "⚔️ 竞品对标分析"),
        ]
        let hasAny = fields.contains { !normalizedLines(aiData[$0.0]).isEmpty }   // 任一有内容才显示区块
        if hasAny {
            SectionTitle(text: "AI 优化建议")
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fields, id: \.0) { f in
                        let lines = normalizedLines(aiData[f.0])   // 值归一为行列表
                        if !lines.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.1).font(.system(size: 13, weight: .semibold)).foregroundColor(T.primary)   // 区块标题
                                ForEach(lines, id: \.self) { line in
                                    Text("· \(line)").font(.system(size: 13)).foregroundColor(T.textMain)   // 逐行圆点
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 小组件

    /// 信息行：可释义问号 + 标签 + 右对齐值；长按弹「拷贝」菜单
    private func infoLine(_ label: String, _ value: String, color: Color = T.textMain) -> some View {
        HStack(alignment: .top) {
            tipIcon(WorkTips[label] != nil, label)   // 有释义才显示问号
            Text(label).font(.system(size: 13)).foregroundColor(T.textSub)
            Spacer()
            Text(value.isEmpty ? "-" : value)        // 空值显示占位
                .font(.system(size: 13)).foregroundColor(color)
                .multilineTextAlignment(.trailing)
                .copyable(value)                     // 长按复制（对齐安卓数据行）
        }
        .padding(.vertical, 3)
    }

    /// 释义问号图标（无释义时隐藏）
    private func tipIcon(_ show: Bool, _ label: String) -> some View {
        Group {
            if show, let body = WorkTips[label] {
                Button { tip = (label, body) } label: {   // 点开释义弹窗
                    Image(systemName: "questionmark.circle").font(.system(size: 10)).foregroundColor(T.textSub.opacity(0.75))
                }
                .padding(.trailing, 2)
            }
        }
    }

    /// 释义弹窗：遮罩可点关闭 + 标题/正文/知道了按钮
    private func tipDialog(_ t: (String, String)) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { tip = nil }   // 点遮罩关闭
            VStack(alignment: .leading, spacing: 12) {
                Text(t.0).font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)   // 标题
                Text(t.1).font(.system(size: 13)).foregroundColor(T.textSub)   // 正文
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

    /// 拉服务端查询记录（前 10 条，失败静默；对齐安卓查询记录区容量）
    private func loadRecent() {
        Task {
            if let d = try? await Network.post("v2/query/history", body: [
                "user_email": SessionStore.email, "page": 1, "page_size": 10,
            ]) {
                await MainActor.run { recentList = d["videos"].arr }
            }
        }
    }

    /// 指标取文本：数字取整（完整数字不缩写）/字符串非空才显示
    private func metricText(_ st: J, _ key: String) -> String? {
        let v = st[key]
        if !v.exists { return nil }
        if let d = v.dbl { return String(Int64(d)) }   // 完整数字不缩写
        if let s = v.str { return s.isEmpty ? nil : s }
        return nil
    }

    /// 指标 key → 展示名（MetricOrder 查找）
    private func metricName(_ key: String) -> String? {
        MetricOrder.first { $0.key == key }?.label
    }

    /// 分辨率行（宽高有效才拼）
    private func resolution(_ r: J) -> String {
        guard let w = r["width"].int, let h = r["height"].int, w > 0, h > 0 else { return "" }
        return "\n分辨率：\(w)×\(h)"
    }

    /// ISO 时间 → 可读格式（失败原样返回）
    private func timeText(_ raw: String) -> String {
        if let d = Fmt.time(raw) { return Fmt.full(d) }
        return raw
    }

    /// 销售线索多形态归一（布尔/数字/字符串）
    private func salesClues(_ v: Any) -> String {
        if let b = v as? Bool { return b ? "有" : "无" }
        if let n = v as? NSNumber { return n.intValue > 0 ? "\(n.intValue)条" : "无" }
        if let s = v as? String { return s }
        return "-"
    }

    /// 热搜词三态解析（数组 / JSON 字符串 / 纯文本单值）
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
        func rate(_ k: String, _ base: Double) -> Double {   // 单维度：数量/播放÷行业基准×50 封顶
            guard let c = st[k].dbl else { return 6 }
            return min(100, max(6, (c / play) / base * 50))
        }
        return [rate("like_count", 0.03), rate("comment_count", 0.005), rate("share_count", 0.008),
                rate("collect_count", 0.008), rate("download_count", 0.001)]   // 五维基准（点赞/评论/分享/收藏/下载）
    }

    /// 雷达维度标签：各维度实际占比百分数
    private func radarLabels(_ st: J, _ play: Double) -> [String] {
        func pct(_ k: String) -> String {
            guard let c = st[k].dbl else { return "0%" }
            return String(format: "%.2f%%", c / play * 100)
        }
        return ["点赞 \(pct("like_count"))", "评论 \(pct("comment_count"))", "分享 \(pct("share_count"))",
                "收藏 \(pct("collect_count"))", "下载 \(pct("download_count"))"]
    }

    // MARK: - 主查询

    /// 剪贴板粘贴输入框（对齐权重分析页 paste）
    private func paste() {
        if let s = UIPasteboard.general.string, !s.trimmingCharacters(in: .whitespaces).isEmpty {
            input = s.trimmingCharacters(in: .whitespaces)
            snackbar = "已粘贴，点击「立即分析」开始"
        } else {
            snackbar = "剪贴板是空的，先去复制分享链接吧"
        }
    }

    /// 手动查询：本地提 ID（失败走服务端短链解析）→ v2/query/douyin
    private func doQuery() {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请输入作品链接或ID"; return }   // 空输入拦截
        let target = LinkParser.extractVideoTarget(raw)   // 文案中提取 URL/ID
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                var id = target.id
                if id == nil {                            // 本地提不出 → 服务端解析短链
                    guard let url = target.url else { throw ApiError.business("无法识别作品ID，请检查链接") }
                    let pd = try await Network.post("query/parse-link", body: ["douyin_url": url])
                    id = pd["video_id"].str
                }
                guard let wid = id, !wid.isEmpty else {
                    throw ApiError.business("无法识别作品ID，请检查链接")
                }
                await MainActor.run { input = wid }       // 输入框回填规范化 ID
                let d = try await Network.post("v2/query/douyin", body: [
                    "works_ids": [wid],
                    "user_email": SessionStore.email,
                    "include_play": true,                 // 附带播放数据
                ])
                let r0 = d["results"][0]
                if !r0.exists {                           // 空结果抛服务端文案
                    throw ApiError.business(d["text"].str ?? "查询失败，请稍后重试")
                }
                await MainActor.run {
                    result = r0
                    resultTitle = r0["ai_title"].str ?? "\(r0["owner_nickname"].str ?? "未知作者") 的作品"   // 标题兜底
                    SessionStore.pushHistory(SessionStore.workHistoryKey, id: wid, name: r0["desc"].str ?? wid)   // 记足迹
                    history = SessionStore.history(SessionStore.workHistoryKey)
                    bus.setBalance(d["new_balance"].dbl)  // 同步扣费后余额
                    // 本地即时自增：不等 profile 回包，顶部「今日已用/剩 N 次」当场更新
                    bus.usedToday += 1
                    if bus.todayRemaining > 0 { bus.todayRemaining -= 1 }
                    bus.refreshAccount()              // 补拉配额（服务器值校准本地）
                }
            } catch let e as ApiError {
                await MainActor.run { self.error = e.errorDescription ?? "" }
            } catch {
                await MainActor.run { self.error = "查询失败，请稍后重试" }
            }
        }
    }

    /// 直通查询：先查数据再自动 AI（对齐 analyzeWorkById）
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
                    SessionStore.pushHistory(SessionStore.workHistoryKey, id: awemeId, name: r0["desc"].str ?? awemeId)   // 记足迹
                    history = SessionStore.history(SessionStore.workHistoryKey)
                    bus.setBalance(d["new_balance"].dbl)
                    // 直通查询同样计一次配额，本地即时自增后由 profile 校准
                    bus.usedToday += 1
                    if bus.todayRemaining > 0 { bus.todayRemaining -= 1 }
                    bus.refreshAccount()              // 补拉配额（服务器值校准本地）
                }
                doAiAnalyze()                             // 数据到手即自动启动 AI
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "查询失败" }
            }
        }
    }

    // MARK: - AI 分析（5s × 60 轮询，连错 5 次放弃）

    /// AI 分析：建任务 → 60×5s 轮询结果 → 暂存 aiResultData 展示
    private func doAiAnalyze() {
        guard let r = result else { return }
        guard let awemeId = r["aweme_id"].str, !awemeId.isEmpty else {   // 无 ID 无法分析
            aiError = "未找到作品ID，无法执行AI分析"
            return
        }
        guard !aiAnalyzing else { return }        // 进行中防重入
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
                var failCnt = 0                   // 连续网络错误计数
                for _ in 0..<60 {                 // 最多 5 分钟
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    do {
                        let rd = try await Network.get("v2/query/ai/analyze_result", query: ["task_id": taskId])
                        failCnt = 0               // 成功响应即清零
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
                        if status == "failed" {   // 任务失败立即抛出
                            throw ApiError.business(rd["msg"].str ?? "AI分析失败")
                        }
                    } catch let e as ApiError {   // 业务错误直接终止
                        throw e
                    } catch {                     // 网络错误容错累计
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
    "发布时间": "作品发布的具体时间",
    "是否带货": "作品是否挂载商品（购物车/小黄车）",
    "产品类型": "挂载商品的类型或带货形式",
    "销售线索": "作品带来的销售线索数量",
    "商品标题": "挂载商品的名称",
    "已售": "该商品的累计销量",
    "促销信息": "商品的促销活动说明（如限时折扣/赠品）",
    "查询状态": "本次查询是否成功获取作品数据",
    "限流": "作品是否被平台限制推荐，限流后曝光量会骤降",
]

extension View {
    /// 长按弹出「拷贝」菜单（对齐安卓数据行长按复制）；空值不弹
    func copyable(_ text: String?) -> some View {
        contextMenu {
            if let t = text, !t.isEmpty {
                Button {
                    UIPasteboard.general.string = t   // 写入系统剪贴板
                } label: { Label("拷贝", systemImage: "doc.on.doc") }
            }
        }
    }
}
