import SwiftUI

// ============================================================================
// WeightHistoryView.swift — 权重查询历史页
// 职责：AI 报告列表（分页/下拉刷新/详情弹层）+ 本地记录双 Tab，
//       条目可回跳权重页直查（对齐安卓 WeightHistoryScreen.kt）
// ============================================================================

/// 权重查询历史（对齐安卓 WeightHistoryScreen.kt：Tab 双列表 + AI 报告详情）
struct WeightHistoryView: View {
    var onBack: () -> Void
    var onQuery: (String) -> Void   // 点记录 → 返回查询页直查

    @State private var tab = 0   // 0=AI报告 1=本地记录
    @State private var list: [J] = []                    // 云端 AI 报告列表
    @State private var page = 1                          // 当前已加载页码
    @State private var total = 0                         // 云端总条数（预加载判据）
    @State private var loading = false                   // 分页加载中（防重入）
    @State private var error = ""                        // 首屏错误文案
    @State private var local: [SessionStore.HistoryEntry] = []  // 本地记录缓存
    @State private var detail: J? = nil                  // 当前查看的报告详情（nil=关闭）
    @State private var snackbar = ""                     // 删除/跳转轻提示
    @State private var rowTip: (String, String)? = nil   // 指标释义弹窗
    @State private var deleting: J? = nil                // 待删除确认的记录（nil=关闭）
    @ObservedObject private var bus = SessionBus.shared  // 全局总线（跳作品页直查）

    var body: some View {
        ZStack {
            TechBackground()                             // 科技感背景
            VStack(spacing: 0) {
                NavBar(title: "查询历史", back: onBack)
                tabBar                                   // AI 报告/本地记录切换
                if tab == 0 {
                    serverList
                } else {
                    localList
                }
            }
            if let d = detail { detailSheet(d) }         // 报告详情浮层（覆盖全屏）
            if let t = rowTip { tipDialog(t) }           // 指标释义弹窗
        }
        .snackbar($snackbar)
        .confirmationDialog("确定删除这条分析记录？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {          // 确认删除
                if let d = deleting { doDelete(d) }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        }
        .onAppear {
            if tab == 0 && list.isEmpty { load(reset: true) }  // 首次进入拉首页
            local = SessionStore.history(SessionStore.weightHistoryKey)  // 本地即时刷新
        }
    }

    /// AI 报告/本地记录分段切换条（选中渐变胶囊）
    private var tabBar: some View {
        HStack(spacing: 0) {
            segBtn("AI 报告", 0)
            segBtn("本地记录", 1)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 单个分段按钮：选中态渐变底+深色字
    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            if idx == 0 && list.isEmpty { load(reset: true) }  // 首次切回 AI 报告补拉
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - AI 报告列表（分页）

    /// AI 报告列表：下拉刷新 + 触底预加载 + 点击开详情
    private var serverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if list.isEmpty && !loading {            // 空态/错误态
                    EmptyState(icon: "doc.text.magnifyingglass", text: error.isEmpty ? "暂无 AI 权重分析记录" : error)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, r in
                    Button {                             // 整卡可点 → 打开详情浮层
                        detail = r
                    } label: {
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                NetImage(url: str(r, "avatar_url", "avatarUrl"), size: 46).clipShape(Circle())  // 头像（双字段名兼容）
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(str(r, "nickname") ?? "未知昵称").font(.system(size: 14, weight: .semibold)).foregroundColor(T.textMain)  // 昵称
                                    Text("权重分 \(str(r, "weight_score") ?? "-") · \(str(r, "weight_desc") ?? "")")  // 分数+描述一行
                                        .font(.system(size: 12)).foregroundColor(T.warn).lineLimit(1)
                                    Text("健康 \(str(r, "health_score") ?? "-") · 活跃 \(str(r, "activity_score") ?? "-") · 粉丝 \((str(r, "follower_count") ?? "0").numFmtCn)")  // 摘要行（对齐安卓卡）
                                        .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                    Text((str(r, "last_query_time") ?? "").replacingOccurrences(of: "T", with: " "))  // 查询时间可读化
                                        .font(.system(size: 11)).foregroundColor(T.textSub)
                                }
                                Spacer()
                                Button {                      // 删除（对齐安卓卡右上角 trash）
                                    deleting = r
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 13)).foregroundColor(T.danger)
                                }
                                .padding(.trailing, 2)
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)  // 可点暗示
                            }
                        }
                    }
                    .onAppear {
                        // 触底翻页
                        if i == list.count - 2 && list.count < total { load(reset: false) }
                    }
                }
                if loading { ProgressView().tint(T.primary).padding(.vertical, 10) }  // 底部加载指示
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { load(reset: true) }               // 下拉刷新回首页
    }

    /// 分页拉取 AI 报告：reset 回首页覆盖，否则追加
    private func load(reset: Bool) {
        if loading { return }                            // 防重入
        loading = true
        if reset { page = 1; error = "" }                // 重拉复位页码/错误
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/weight/history", body: [
                    "user_email": SessionStore.email,    // 以邮箱定位用户
                    "page": reset ? 1 : page + 1,
                    "page_size": 10,
                ])
                let items = d["list"].arr
                await MainActor.run {
                    total = d["total"].int ?? 0
                    page = reset ? 1 : page + 1          // 推进页码
                    if reset { list = items } else { list += items }  // 覆盖或追加
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    // MARK: - 本地记录

    /// 本地记录列表：查询足迹，支持再查/单删
    private var localList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if local.isEmpty {                       // 本地空态
                    EmptyState(icon: "clock", text: "暂无本地查询记录")
                }
                ForEach(local) { h in
                    GlassCard(padding: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "link").font(.system(size: 12)).foregroundColor(T.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.name.isEmpty ? h.id : h.name)              // 名称缺省显示 ID
                                    .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(1)
                                Text(Fmt.full(Date(timeIntervalSince1970: h.ts / 1000)))  // 时间戳可读化
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                            Spacer()
                            Button {
                                onQuery(h.id)            // 再查一次：回权重页直查
                            } label: {
                                Text("再查一次").font(.system(size: 12)).foregroundColor(T.primary)
                            }
                            Button {                     // 删除：落盘并刷新
                                SessionStore.removeHistory(SessionStore.weightHistoryKey, id: h.id)
                                local = SessionStore.history(SessionStore.weightHistoryKey)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 13)).foregroundColor(T.danger)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - 删除 / 释义 / 数据兼容

    /// 删除 AI 报告记录：POST weight/delete（user_email + record_id，与安卓/Web 同参）
    private func doDelete(_ d: J) {
        guard let id = d["id"].int ?? d["record_id"].int else { return }
        Task {
            do {
                _ = try await Network.post("v2/query/weight/delete", body: [
                    "user_email": SessionStore.email, "record_id": id,
                ])
                await MainActor.run {
                    list.removeAll { ($0["id"].int ?? -1) == id || ($0["record_id"].int ?? -2) == id }  // 本地移除
                    total = max(0, total - 1)
                    snackbar = "已删除该记录"
                }
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "删除失败，请稍后重试" }
            }
        }
    }

    /// effective 兼容：weight_info.data.rowInfo != null ? weight_info.data : 原始（对齐 WeightView）
    private func effective(_ d: J) -> J {
        let inner = d["weight_info"]["data"]
        if !inner["rowInfo"].arr.isEmpty || inner["rowInfo"].exists { return inner }
        return d
    }

    /// 指标释义弹窗（遮罩可点关闭，样式对齐 WeightView.tipDialog）
    private func tipDialog(_ t: (String, String)) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { rowTip = nil }
            VStack(alignment: .leading, spacing: 12) {
                Text(t.0).font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)
                ScrollView(showsIndicators: false) {
                    Text(t.1).font(.system(size: 13)).foregroundColor(T.textSub)
                }
                .frame(maxHeight: 200)
                Button {
                    rowTip = nil
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

    // MARK: - AI 报告详情（5 区块）

    /// 报告详情浮层：基本信息卡 + AI 五区块（空洞时缺省隐藏）
    private func detailSheet(_ d: J) -> some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea().onTapGesture { detail = nil }  // 点遮罩关闭
            VStack(spacing: 12) {
                HStack {
                    Text(str(d, "nickname") ?? "AI 权重分析报告")  // 标题（昵称兜底）
                        .font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain).lineLimit(1)
                    Spacer()
                    Button { detail = nil } label: {     // 关闭按钮
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(T.textSub)
                    }
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 基本信息
                        GlassCard(padding: 12) {
                            VStack(spacing: 4) {
                                InfoRow(label: "账号", value: str(d, "account") ?? "-")
                                InfoRow(label: "权重分", value: str(d, "weight_score") ?? "-", valueColor: T.primary)  // 分数高亮
                                InfoRow(label: "权重描述", value: str(d, "weight_desc") ?? "-")
                                InfoRow(label: "健康度", value: str(d, "health_desc") ?? "-", valueColor: .green)
                                InfoRow(label: "粉丝数", value: (str(d, "follower_count") ?? "0").numFmtCn)  // 万/亿缩写
                                InfoRow(label: "查询时间", value: (str(d, "last_query_time") ?? "").replacingOccurrences(of: "T", with: " "))
                            }
                        }
                        // 权重指标行（row_info 还原，对齐安卓历史详情展开区）
                        let rows = effective(d)["rowInfo"].arr
                        if !rows.isEmpty {
                            Text("权重指标").font(.system(size: 14, weight: .semibold)).foregroundColor(T.primary)
                            GlassCard(padding: 12) {
                                VStack(spacing: 2) {
                                    let coverRows = rows.filter { $0["isShow"].bool && $0["rowValueType"].int == 1 && !$0["rowValueDetail"].arr.isEmpty }
                                    ForEach(Array(rows.filter { $0["isShow"].bool && !($0["rowValueType"].int == 1 && !$0["rowValueDetail"].arr.isEmpty) }.enumerated()),
                                            id: \.offset) { _, row in
                                        WeightRowView(row: row, onTapTip: { rowTip = $0 }, onWork: { awemeId in
                                            bus.pendingWorkId = awemeId   // 直通车：跳作品页直查
                                            detail = nil
                                            snackbar = "已切换到作品分析页"
                                        })
                                        Divider().overlay(Color.white.opacity(0.05))
                                    }
                                    ForEach(Array(coverRows.enumerated()), id: \.offset) { _, row in
                                        CoverGridRow(row: row, onWork: { awemeId in
                                            bus.pendingWorkId = awemeId
                                            detail = nil
                                            snackbar = "已切换到作品分析页"
                                        })
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                        }
                        // 5 区块
                        ForEach(WeightConst.AIWeightSections, id: \.key) { sec in
                            // 历史详情：ai_report 内 5 字段或根级
                            let body = d["ai_report"][sec.key].str ?? d[sec.key].str ?? ""
                            if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 空区块跳过
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(sec.title).font(.system(size: 14, weight: .semibold)).foregroundColor(T.primary)
                                        Button {         // 问号图标：关闭详情（引导回列表重查）
                                            detail = nil
                                        } label: {
                                            Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundColor(T.textSub)
                                        }
                                    }
                                    Text(body).font(.system(size: 13)).foregroundColor(T.textMain)  // 正文
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(T.stroke, lineWidth: 1))
            .padding(.horizontal, 14).padding(.vertical, 30)
        }
    }
}

extension String {
    /// 万/亿缩写（数字字符串）
    var numFmtCn: String {
        guard let v = Double(self) else { return self }  // 非数字原样返回
        let a = abs(v)
        if a >= 1e8 { return String(format: "%.1f亿", v / 1e8) }   // 亿级
        if a >= 1e4 { return String(format: "%.1f万", v / 1e4) }   // 万级
        return String(Int64(v))                          // 千以内取整
    }
}
