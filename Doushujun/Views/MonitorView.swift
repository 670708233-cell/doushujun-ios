import SwiftUI

// ============================================================================
// MonitorView.swift — 作品数据监控页
// 职责：监控任务列表（30s 自动刷新/删除确认）+ 三步新建流程（链接→时长→完成）
//       + 趋势图入口 + 权重页直通车预填（对齐安卓 MonitorScreen + CreateTaskFlow）
// ============================================================================

/// 作品数据监控（对齐安卓 MonitorScreen + CreateTaskFlow）
struct MonitorView: View {
    @ObservedObject private var bus = SessionBus.shared

    @State private var tasks: [J] = []                   // 监控任务列表
    @State private var loading = false                   // 加载中（防重入）
    @State private var error = ""                        // 错误文案（空态显示）
    @State private var showCreate = false                // 新建流程弹窗
    @State private var openChart: ChartTask? = nil       // 趋势图弹窗（item 驱动）
    @State private var confirmDelete: J? = nil           // 待删除任务（确认弹窗）
    @State private var snackbar = ""                     // 轻提示
    @State private var timer: Timer? = nil               // 30s 自动刷新定时器

    var body: some View {
        ZStack {
            TechBackground()                             // 科技感背景
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()                    // 公告栏
                    GradientBanner(title: "作品数据监控", subtitle: "24小时自动采集播放/点赞/评论/分享趋势")  // 横幅

                    // 新建监控按钮
                    Button {
                        bus.pendingTaskLink = nil        // 清残留直通车信号
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
                    if tasks.isEmpty && !loading {       // 空态/错误态
                        GlassCard {
                            EmptyState(icon: "chart.line.uptrend.xyaxis", text: error.isEmpty ? "暂无监控任务\n点击上方「新建监控任务」开始" : error)
                        }
                    }
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                        taskCard(t)
                    }
                    if loading && !tasks.isEmpty {       // 顶部刷新指示（有内容时）
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
            timer?.invalidate()                          // 防重复建定时器
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in load() }
        }
        .onDisappear { timer?.invalidate(); timer = nil }  // 离页停表
        .refreshable { load() }                          // 下拉手动刷新
        .sheet(isPresented: $showCreate) {
            CreateTaskFlow(onCreated: {
                showCreate = false
                load()                                   // 创建成功回刷列表
                snackbar = "监控任务创建成功"
            }, onCancel: { showCreate = false })
        }
        .sheet(item: $openChart) { t in
            MonitorChartView(task: t, onClose: { openChart = nil })  // 趋势图弹窗
        }
        .onChange(of: bus.pendingTaskLink) { link in
            // 直通车：权重页封面 → 新建监控预填
            if let l = link {
                bus.pendingTaskLink = nil                // 消费信号防重复触发
                showCreate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {  // 等弹窗就绪再发通知
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
            Text("删除后将停止采集「\(confirmDelete?["video_title"].str ?? "")」的数据，已采集数据保留。确定删除？")  // 明确告知数据保留
        }
    }

    // MARK: - 任务卡

    /// 单张任务卡：封面/标题/剩余天数/4 指标 + 趋势图/删除按钮
    private func taskCard(_ t: J) -> some View {
        let st = t["stats"].exists ? t["stats"] : t      // 指标来源：stats 子对象或根级兼容
        let days = Fmt.daysLeft(t["expire_time"].str ?? t["end_time"].str ?? "")  // 剩余天数（双字段兼容）
        return Button {
            openChart = ChartTask(j: t)                  // 整卡可点开趋势图
        } label: {
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        // 封面：后端 gettasklist 返回字段为 content_image（原 cover 字段不存在→封面空白实证）
                        NetImage(url: t["content_image"].str, width: 52, height: 68)   // 竖版封面
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            // 标题：后端字段 content_title（原 video_title 不存在→「未命名作品」实证）
                            Text(t["content_title"].str ?? "未命名作品")
                                .font(.system(size: 14, weight: .medium)).foregroundColor(T.textMain).lineLimit(2)
                            HStack(spacing: 6) {
                                Text(days > 0 ? "剩余 \(days) 天" : "已到期")   // 剩余/到期状态
                                    .font(.system(size: 11))
                                    .foregroundColor(days > 0 ? .green : T.danger)
                                Text("· \(Fmt.mdhm(Fmt.time(t["created_at"].str ?? "") ?? Date()) )")  // 创建时间（后端字段 created_at）
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                    }
                    // 4 指标
                    HStack {
                        MetricCell(value: (st["play"].dbl ?? st["play_count"].dbl ?? 0).numFmtCn2, label: "播放", color: T.primary)      // 播放（双字段兼容）
                        MetricCell(value: (st["like"].dbl ?? st["like_count"].dbl ?? 0).numFmtCn2, label: "点赞", color: T.secondary)
                        MetricCell(value: (st["comment"].dbl ?? st["comment_count"].dbl ?? 0).numFmtCn2, label: "评论", color: T.warn)
                        MetricCell(value: (st["share"].dbl ?? st["share_count"].dbl ?? 0).numFmtCn2, label: "分享", color: .green)
                    }
                    HStack {
                        Button {
                            openChart = ChartTask(j: t)  // 查看趋势图
                        } label: {
                            Text("查看趋势图").font(.system(size: 12, weight: .medium)).foregroundColor(T.primary)
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                        }
                        Button {
                            confirmDelete = t            // 触发删除确认
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

    /// 拉取任务列表：tasks 数组或根数组双兼容
    private func load() {
        if loading { return }                            // 防重入（定时器+手动并发）
        loading = true
        Task {
            defer { loading = false }
            do {
                // 后端路由为 POST（GET 请求 404 实证），参数与安卓对齐
                let d = try await Network.post("monitor/gettasklist", body: ["user_email": SessionStore.email])
                var arr = d["list"].arr                    // 后端首选 data.list
                if arr.isEmpty { arr = d["tasks"].arr }    // 旧版 tasks 字段兜底
                if arr.isEmpty { arr = d.arr }             // 根级数组兜底
                await MainActor.run { tasks = arr; error = "" }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    /// 删除任务：成功后本地移除并提示
    private func doDelete(_ t: J) {
        guard let id = t["task_id"].str else { return }
        Task {
            do {
                _ = try await Network.post("monitor/delete-task", body: [
                    "user_email": SessionStore.email, "task_id": id,
                ])
                await MainActor.run {
                    tasks.removeAll { $0["task_id"].str == id }  // 本地同步移除
                    snackbar = "任务已删除"
                }
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "删除失败" }
            }
        }
    }
}

extension Notification.Name {
    static let monitorPrefill = Notification.Name("monitorPrefill")  // 直通车预填通知名
}

extension Double {
    /// 万/亿缩写（指标数值展示用）
    var numFmtCn2: String {
        let a = abs(self)
        if a >= 1e8 { return String(format: "%.1f亿", self / 1e8) }
        if a >= 1e4 { return String(format: "%.1f万", self / 1e4) }
        return String(Int64(self))
    }
}

/// 新建监控三步流程（对齐安卓 CreateTaskFlow.kt）
struct CreateTaskFlow: View {
    var onCreated: () -> Void                        // 创建成功回调
    var onCancel: () -> Void                         // 取消回调

    @State private var step = 1              // 1 链接 → 2 预览+时长 → 3 完成
    @State private var link = ""                     // 链接输入
    @State private var parsing = false               // 解析中
    @State private var videoId = ""                  // 解析出的作品 ID
    @State private var videoInfo: J? = nil           // 预览详情（封面/标题）
    @State private var duration = 30                 // 监控时长（默认 30 天）
    @State private var submitting = false            // 创建中
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss

    private let durations = [7, 14, 30]              // 可选时长档位

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

                        switch step {                // 按步骤装配内容
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
                    Button("取消") { onCancel() }.foregroundColor(T.textSub)  // 左上取消
                }
            }
        }
        .navigationViewStyleCompat()
        .snackbar($error)
        .onAppear {
            // 直通车预填
            NotificationCenter.default.addObserver(forName: .monitorPrefill, object: nil, queue: .main) { n in
                if let l = n.object as? String {     // 收到通知：回填并自动解析
                    link = l
                    parse()
                }
            }
            if let l = SessionBus.shared.pendingTaskLink {  // 总线信号兜底（通知丢失场景）
                link = l
                parse()
            }
        }
    }

    /// 步骤圆点：已到步骤渐变高亮
    private func stepDot(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(step >= n ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.12)))
                .frame(width: 24, height: 24)
                .overlay(Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundColor(step >= n ? T.bg : T.textSub))
            Text(label).font(.system(size: 12)).foregroundColor(step >= n ? T.textMain : T.textSub)
        }
    }

    /// 步骤间连接线：已走过段落主色
    private func stepLine(_ n: Int) -> some View {
        Rectangle().fill(step > n ? T.primary.opacity(0.6) : Color.white.opacity(0.10)).frame(height: 2)
    }

    // 步骤1：粘贴链接
    private var stepLink: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "① 粘贴作品分享链接")
                TextField("粘贴作品分享链接", text: $link)
                    .font(.system(size: 14)).foregroundColor(T.textMain)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundColor(T.danger) }  // 行内错误
                HStack(spacing: 10) {
                    PrimaryButton(title: "解析链接", loading: parsing) { parse() }
                    Button {         // 剪贴板粘贴
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
                if let v = videoInfo {               // 预览卡（解析详情可能为 nil）
                    HStack(spacing: 12) {
                        NetImage(url: v["cover_info"]["default_cover"].str ?? v["aweme_cover"].str, width: 56, height: 74)  // 封面双字段兼容
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
                                .fill(duration == d ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.05))))  // 选中渐变底
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(duration == d ? .clear : T.stroke, lineWidth: 1))
                        }
                    }
                }
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundColor(T.danger) }
                PrimaryButton(title: "创建监控任务", loading: submitting) { create() }
                Button { step = 1 } label: {         // 回上一步换作品
                    Text("← 重新选择作品").font(.system(size: 12)).foregroundColor(T.textSub)
                }
            }
        }
    }

    // 步骤3：完成
    private var stepDone: some View {
        GlassCard {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundColor(.green)  // 成功大图标
                Text("监控任务创建成功").font(.system(size: 16, weight: .bold)).foregroundColor(T.textMain)
                Text("平台将每 2 小时自动采集一次数据\n采集完成后可在趋势图中查看")
                    .font(.system(size: 12)).foregroundColor(T.textSub)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "完成") { onCreated() }
            }
        }
    }

    /// 解析链接：本地正则直提 ID，失败走服务端 parse-link 兜底
    private func parse() {
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请粘贴作品链接"; return }
        parsing = true
        error = ""
        Task {
            defer { parsing = false }
            do {
                var id = LinkParser.extractAwemeId(raw)          // 先本地正则
                if id == nil {                                   // 本地提不出 → 服务端短链解析
                    guard let url = LinkParser.extractVideoTarget(raw).url, !url.isEmpty else {
                        throw ApiError.business("无法识别作品，请检查链接是否完整")
                    }
                    let d = try await Network.post("query/parse-link", body: ["douyin_url": url])
                    id = d["video_id"].str
                }
                guard let vid = id, !vid.isEmpty else {
                    throw ApiError.business("无法识别作品，请检查链接是否完整")
                }
                videoId = vid
                // 预览详情（失败不阻塞）
                if let d = try? await Network.post("monitor/douyin_video_detail", body: ["user_email": SessionStore.email, "aweme_id": vid]) {
                    let v = d["video_info"].exists ? d["video_info"] : d  // 结构双兼容
                    await MainActor.run { videoInfo = v.exists ? v : nil }
                }
                await MainActor.run { step = 2 }                 // 进步骤 2
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "解析失败" }
            }
        }
    }

    /// 创建监控任务：成功进步骤 3 完成页
    private func create() {
        submitting = true
        error = ""
        Task {
            defer { submitting = false }
            do {
                let v = videoInfo                                // 预览详情（可能 nil；后端 douyin_video_detail 可能不含 publish_time）
                // 发布时间三态解析（对齐安卓 parseTime：数字毫秒/秒 → 字符串日期 → 兜底当前时间；
                // 兜底必填——后端 empty($publishTime) 直接拒单「发布时间不能为空」实证）
                let pt: Int = {
                    if let d = (v?["publish_time"].str ?? v?["create_time"].str).flatMap({ Double($0) }) {
                        return d > 1e12 ? Int(d / 1000) : Int(d)          // 数字形态：毫秒转秒/秒原样
                    }
                    if let s = v?["publish_time"].str ?? v?["create_time"].str {  // 字符串日期形态：
                        let f = DateFormatter()                           // "yyyy-MM-dd HH:mm:ss"（后端常规存式）
                        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        if let t = f.date(from: s) { return Int(t.timeIntervalSince1970) }
                        f.dateFormat = "yyyy-MM-dd"                       // 纯日期形态兜底
                        if let t = f.date(from: s) { return Int(t.timeIntervalSince1970) }
                    }
                    return Int(Date().timeIntervalSince1970)              // 全部取不到：当前时间兜底（对齐安卓 now/1000）
                }()
                _ = try await Network.post("monitor/create-task", body: [
                    "user_email": SessionStore.email,
                    "aweme_id": videoId,                         // 后端参数名（原 video_id 404 实证）
                    "content_title": v?["desc"].str ?? v?["title"].str ?? "未命名作品",  // 标题（desc 为预览实证字段）
                    "content_url": v?["share_url"].str ?? "",
                    // 封面四层兜底：cover_info.default_cover 为预览实证结构，其余对齐安卓
                    "content_image": v?["cover_info"]["default_cover"].str ?? v?["aweme_cover"].str ?? v?["cover"].str ?? v?["cover_url"].str ?? "",
                    "publish_time": pt,                          // 秒级时间戳（上面三态解析）
                    "monitor_duration": duration,                // 后端参数名（原 duration_days）
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
    /// 标题 inline 模式包装
    func navigationBarTitleDisplayModeCompat(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .font(.system(size: 16, weight: .semibold))
    }

    /// 竖排样式（避免 iOS15 双栏）
    func navigationViewStyleCompat() -> some View {
        navigationViewStyle(.stack)
    }
}
