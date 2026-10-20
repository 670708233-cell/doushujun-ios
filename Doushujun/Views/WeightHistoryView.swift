import SwiftUI

/// 权重查询历史（对齐安卓 WeightHistoryScreen.kt：Tab 双列表 + AI 报告详情）
struct WeightHistoryView: View {
    var onBack: () -> Void
    var onQuery: (String) -> Void   // 点记录 → 返回查询页直查

    @State private var tab = 0   // 0=AI报告 1=本地记录
    @State private var list: [J] = []
    @State private var page = 1
    @State private var total = 0
    @State private var loading = false
    @State private var error = ""
    @State private var local: [SessionStore.HistoryEntry] = []
    @State private var detail: J? = nil

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "查询历史", back: onBack)
                tabBar
                if tab == 0 {
                    serverList
                } else {
                    localList
                }
            }
            if let d = detail { detailSheet(d) }
        }
        .onAppear {
            if tab == 0 && list.isEmpty { load(reset: true) }
            local = SessionStore.history(SessionStore.weightHistoryKey)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            segBtn("AI 报告", 0)
            segBtn("本地记录", 1)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            if idx == 0 && list.isEmpty { load(reset: true) }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - AI 报告列表（分页）

    private var serverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if list.isEmpty && !loading {
                    EmptyState(icon: "doc.text.magnifyingglass", text: error.isEmpty ? "暂无 AI 权重分析记录" : error)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, r in
                    Button {
                        detail = r
                    } label: {
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                NetImage(url: str(r, "avatar_url", "avatarUrl"), size: 46).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(str(r, "nickname") ?? "未知昵称").font(.system(size: 14, weight: .semibold)).foregroundColor(T.textMain)
                                    Text("权重分 \(str(r, "weight_score") ?? "-") · \(str(r, "weight_desc") ?? "")")
                                        .font(.system(size: 12)).foregroundColor(T.textSub).lineLimit(1)
                                    Text((str(r, "last_query_time") ?? "").replacingOccurrences(of: "T", with: " "))
                                        .font(.system(size: 11)).foregroundColor(T.textSub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                            }
                        }
                    }
                    .onAppear {
                        // 触底翻页
                        if i == list.count - 2 && list.count < total { load(reset: false) }
                    }
                }
                if loading { ProgressView().tint(T.primary).padding(.vertical, 10) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { load(reset: true) }
    }

    private func load(reset: Bool) {
        if loading { return }
        loading = true
        if reset { page = 1; error = "" }
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/weight/history", body: [
                    "user_email": SessionStore.email,
                    "page": reset ? 1 : page + 1,
                    "page_size": 10,
                ])
                let items = d["list"].arr
                await MainActor.run {
                    total = d["total"].int ?? 0
                    page = reset ? 1 : page + 1
                    if reset { list = items } else { list += items }
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    // MARK: - 本地记录

    private var localList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if local.isEmpty {
                    EmptyState(icon: "clock", text: "暂无本地查询记录")
                }
                ForEach(local) { h in
                    GlassCard(padding: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "link").font(.system(size: 12)).foregroundColor(T.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.name.isEmpty ? h.id : h.name)
                                    .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(1)
                                Text(Fmt.full(Date(timeIntervalSince1970: h.ts / 1000)))
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                            Spacer()
                            Button {
                                onQuery(h.id)
                            } label: {
                                Text("再查一次").font(.system(size: 12)).foregroundColor(T.primary)
                            }
                            Button {
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

    // MARK: - AI 报告详情（5 区块）

    private func detailSheet(_ d: J) -> some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea().onTapGesture { detail = nil }
            VStack(spacing: 12) {
                HStack {
                    Text(str(d, "nickname") ?? "AI 权重分析报告")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain).lineLimit(1)
                    Spacer()
                    Button { detail = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(T.textSub)
                    }
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // 基本信息
                        GlassCard(padding: 12) {
                            VStack(spacing: 4) {
                                InfoRow(label: "账号", value: str(d, "account") ?? "-")
                                InfoRow(label: "权重分", value: str(d, "weight_score") ?? "-", valueColor: T.primary)
                                InfoRow(label: "权重描述", value: str(d, "weight_desc") ?? "-")
                                InfoRow(label: "健康度", value: str(d, "health_desc") ?? "-", valueColor: .green)
                                InfoRow(label: "粉丝数", value: (str(d, "follower_count") ?? "0").numFmtCn)
                                InfoRow(label: "查询时间", value: (str(d, "last_query_time") ?? "").replacingOccurrences(of: "T", with: " "))
                            }
                        }
                        // 5 区块
                        ForEach(WeightConst.AIWeightSections, id: \.key) { sec in
                            // 历史详情：ai_report 内 5 字段或根级
                            let body = d["ai_report"][sec.key].str ?? d[sec.key].str ?? ""
                            if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(sec.title).font(.system(size: 14, weight: .semibold)).foregroundColor(T.primary)
                                        Button {
                                            detail = nil
                                        } label: {
                                            Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundColor(T.textSub)
                                        }
                                    }
                                    Text(body).font(.system(size: 13)).foregroundColor(T.textMain)
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
        guard let v = Double(self) else { return self }
        let a = abs(v)
        if a >= 1e8 { return String(format: "%.1f亿", v / 1e8) }
        if a >= 1e4 { return String(format: "%.1f万", v / 1e4) }
        return String(Int64(v))
    }
}
