import SwiftUI

/// 作品数据监控（对齐安卓 MonitorScreen + CreateTaskFlow）
struct MonitorView: View {
    @ObservedObject private var bus = SessionBus.shared

    @State private var tasks: [J] = []
    @State private var loading = false
    @State private var error = ""
    @State private var showCreate = false
    @State private var openChart: ChartTask? = nil
    @State private var confirmDelete: J? = nil
    @State private var snackbar = ""
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()
                    GradientBanner(title: "作品数据监控", subtitle: "24小时自动采集播放/点赞/评论/分享趋势")

                    // 新建监控按钮
                    Button {
                        bus.pendingTaskLink = nil
                        showCreate = true
                    } label: {
                        GlassCard(padding: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundColor(T.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("新建监控任务").font(.system(size: 15, weight: .semibold)).foregroundColor(T.textMain)
                                    Text("粘贴作品链接，选择监控时长，自动采集数据趋势")
                                        .font(.system(size: 11)).foregroundColor(T.textSub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(T.textSub)
                            }
                        }
                    }

                    // 任务卡列表
                    if tasks.isEmpty && !loading {
                        GlassCard {
                            EmptyState(icon: "chart.line.uptrend.xyaxis", text: error.isEmpty ? "暂无监控任务\n点击上方「新建监控任务」开始" : error)
                        }
                    }
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                        taskCard(t)
                    }
                    if loading && !tasks.isEmpty {
                        ProgressView().tint(T.primary).padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .snackbar($snackbar)
        .onAppear {
            load()
            // 30s 自动刷新
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in load() }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
        .refreshable { load() }
        .sheet(isPresented: $showCreate) {
            CreateTaskFlow(onCreated: {
                showCreate = false
                load()
                snackbar = "监控任务创建成功"
            }, onCancel: { showCreate = false })
        }
        .sheet(item: $openChart) { t in
            MonitorChartView(task: t, onClose: { openChart = nil })
        }
        .onChange(of: bus.pendingTaskLink) { link in
            // 直通车：权重页封面 → 新建监控预填
            if let l = link {
                bus.pendingTaskLink = nil
                showCreate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NotificationCenter.default.post(name: .monitorPrefill, object: l)
                }
            }
        }
        .alert("删除任务", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let t = confirmDelete { doDelete(t) }
            }
        } message: {
            Text("删除后将停止采集「\(confirmDelete?["video_title"].str ?? "")」的数据，已采集数据保留。确定删除？")
        }
    }

    // MARK: - 任务卡

    private func taskCard(_ t: J) -> some View {
        let st = t["stats"].exists ? t["stats"] : t
        let days = Fmt.daysLeft(t["expire_time"].str ?? t["end_time"].str ?? "")
        return Button {
            openChart = ChartTask(j: t)
        } label: {
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        NetImage(url: t["cover"].str, width: 52, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t["video_title"].str ?? "未命名作品")
                                .font(.system(size: 14, weight: .medium)).foregroundColor(T.textMain).lineLimit(2)
                            HStack(spacing: 6) {
                                Text(days > 0 ? "剩余 \(days) 天" : "已到期")
                                    .font(.system(size: 11))
                                    .foregroundColor(days > 0 ? .green : T.danger)
                                Text("· \(Fmt.mdhm(Fmt.time(t["create_time"].str ?? "") ?? Date()) )")
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                    }
                    // 4 指标
                    HStack {
                        MetricCell(value: (st["play"].dbl ?? st["play_count"].dbl ?? 0).numFmtCn2, label: "播放", color: T.primary)
                        MetricCell(value: (st["like"].dbl ?? st["like_count"].dbl ?? 0).numFmtCn2, label: "点赞", color: T.secondary)
                        MetricCell(value: (st["comment"].dbl ?? st["comment_count"].dbl ?? 0).numFmtCn2, label: "评论", color: T.warn)
                        MetricCell(value: (st["share"].dbl ?? st["share_count"].dbl ?? 0).numFmtCn2, label: "分享", color: .green)
                    }
                    HStack {
                        Button {
                            openChart = ChartTask(j: t)
                        } label: {
                            Text("查看趋势图").font(.system(size: 12, weight: .medium)).foregroundColor(T.primary)
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                        }
                        Button {
                            confirmDelete = t
                        } label: {
                            Text("删除任务").font(.system(size: 12)).foregroundColor(T.danger)
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(T.danger.opacity(0.10)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 数据

    private func load() {
        if loading { return }
        loading = true
        Task {
            defer { loading = false }
            do {
                let d = try await Network.get("monitor/gettasklist", query: ["user_email": SessionStore.email])
                var arr = d["tasks"].arr
                if arr.isEmpty { arr = d.arr }
                await MainActor.run { tasks = arr; error = "" }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    private func doDelete(_ t: J) {
        guard let id = t["task_id"].str else { return }
        Task {
            do {
                _ = try await Network.post("monitor/deltask", body: [
                    "user_email": SessionStore.email, "task_id": id,
                ])
                await MainActor.run {
                    tasks.removeAll { $0["task_id"].str == id }
                    snackbar = "任务已删除"
                }
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "删除失败" }
            }
        }
    }
}

extension Notification.Name {
    static let monitorPrefill = Notification.Name("monitorPrefill")
}

extension Double {
    var numFmtCn2: String {
        let a = abs(self)
        if a >= 1e8 { return String(format: "%.1f亿", self / 1e8) }
        if a >= 1e4 { return String(format: "%.1f万", self / 1e4) }
        return String(Int64(self))
    }
}

/// 新建监控三步流程（对齐安卓 CreateTaskFlow.kt）
struct CreateTaskFlow: View {
    var onCreated: () -> Void
    var onCancel: () -> Void

    @State private var step = 1              // 1 链接 → 2 预览+时长 → 3 完成
    @State private var link = ""
    @State private var parsing = false
    @State private var videoId = ""
    @State private var videoInfo: J? = nil
    @State private var duration = 30
    @State private var submitting = false
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss

    private let durations = [7, 14, 30]

    var body: some View {
        NavigationView {
            ZStack {
                TechBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 步骤条
                        HStack(spacing: 8) {
                            stepDot(1, "粘贴链接")
                            stepLine(1)
                            stepDot(2, "选择时长")
                            stepLine(2)
                            stepDot(3, "完成")
                        }
                        .padding(.vertical, 6)

                        switch step {
                        case 1: stepLink
                        case 2: stepPreview
                        default: stepDone
                        }
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayModeCompat("新建监控任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onCancel() }.foregroundColor(T.textSub)
                }
            }
        }
        .navigationViewStyleCompat()
        .snackbar($error)
        .onAppear {
            // 直通车预填
            NotificationCenter.default.addObserver(forName: .monitorPrefill, object: nil, queue: .main) { n in
                if let l = n.object as? String {
                    link = l
                    parse()
                }
            }
            if let l = SessionBus.shared.pendingTaskLink {
                link = l
                parse()
            }
        }
    }

    private func stepDot(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(step >= n ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.12)))
                .frame(width: 24, height: 24)
                .overlay(Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundColor(step >= n ? T.bg : T.textSub))
            Text(label).font(.system(size: 12)).foregroundColor(step >= n ? T.textMain : T.textSub)
        }
    }

    private func stepLine(_ n: Int) -> some View {
        Rectangle().fill(step > n ? T.primary.opacity(0.6) : Color.white.opacity(0.10)).frame(height: 2)
    }

    // 步骤1：粘贴链接
    private var stepLink: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "① 粘贴作品分享链接")
                TextField("粘贴抖音分享链接", text: $link)
                    .font(.system(size: 14)).foregroundColor(T.textMain)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundColor(T.danger) }
                HStack(spacing: 10) {
                    PrimaryButton(title: "解析链接", loading: parsing) { parse() }
                    Button {
                        if let s = UIPasteboard.general.string {
                            link = s.trimmingCharacters(in: .whitespaces)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard").foregroundColor(T.primary)
                            .frame(width: 48, height: 50)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                    }
                }
            }
        }
    }

    // 步骤2：预览+时长
    private var stepPreview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "② 确认作品并选择监控时长")
                if let v = videoInfo {
                    HStack(spacing: 12) {
                        NetImage(url: v["cover_info"]["default_cover"].str ?? v["aweme_cover"].str, width: 56, height: 74)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(v["desc"].str ?? "未命名作品").font(.system(size: 13)).foregroundColor(T.textMain).lineLimit(2)
                            Text("作品ID：\(videoId)").font(.system(size: 11)).foregroundColor(T.textSub)
                        }
                        Spacer()
                    }
                }
                Text("监控时长").font(.system(size: 13)).foregroundColor(T.textSub)
                HStack(spacing: 10) {
                    ForEach(durations, id: \.self) { d in
                        Button {
                            duration = d
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(d) 天").font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(duration == d ? T.bg : T.textMain)
                                Text("到期自动停止").font(.system(size: 10))
                                    .foregroundColor(duration == d ? T.bg.opacity(0.8) : T.textSub)
                            }
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(duration == d ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.05))))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(duration == d ? .clear : T.stroke, lineWidth: 1))
                        }
                    }
                }
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundColor(T.danger) }
                PrimaryButton(title: "创建监控任务", loading: submitting) { create() }
                Button { step = 1 } label: {
                    Text("← 重新选择作品").font(.system(size: 12)).foregroundColor(T.textSub)
                }
            }
        }
    }

    // 步骤3：完成
    private var stepDone: some View {
        GlassCard {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundColor(.green)
                Text("监控任务创建成功").font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)
                Text("平台将每 2 小时自动采集一次数据\n采集完成后可在趋势图中查看")
                    .font(.system(size: 12)).foregroundColor(T.textSub)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "完成") { onCreated() }
            }
        }
    }

    private func parse() {
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请粘贴作品链接"; return }
        parsing = true
        error = ""
        Task {
            defer { parsing = false }
            do {
                var id = LinkParser.extractAwemeId(raw)
                if id == nil {
                    let url = LinkParser.extractUrl(raw)
                    let d = try await Network.post("query/parse-link", body: ["douyin_url": url])
                    id = d["video_id"].str
                }
                guard let vid = id, !vid.isEmpty else {
                    throw ApiError.business("无法识别作品，请检查链接是否完整")
                }
                videoId = vid
                // 预览详情（失败不阻塞）
                if let d = try? await Network.post("monitor/video-detail", body: ["user_email": SessionStore.email, "video_id": vid]) {
                    let v = d["video_info"].exists ? d["video_info"] : d
                    await MainActor.run { videoInfo = v.exists ? v : nil }
                }
                await MainActor.run { step = 2 }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "解析失败" }
            }
        }
    }

    private func create() {
        submitting = true
        error = ""
        Task {
            defer { submitting = false }
            do {
                _ = try await Network.post("monitor/create-task", body: [
                    "user_email": SessionStore.email,
                    "video_id": videoId,
                    "duration_days": duration,
                ])
                await MainActor.run { step = 3 }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "创建失败" }
            }
        }
    }
}

// iOS15 兼容：NavigationView 标题与样式
extension View {
    func navigationBarTitleDisplayModeCompat(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .font(.system(size: 16, weight: .semibold))
    }

    func navigationViewStyleCompat() -> some View {
        navigationViewStyle(.stack)
    }
}
