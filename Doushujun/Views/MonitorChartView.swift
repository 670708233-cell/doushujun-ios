import SwiftUI  // UI 框架

/// 监控趋势图（对齐安卓 MonitorChartScreen：4 指标折线 + 累计切换）：
/// 单个监控任务的数据可视化页——封面信息卡、指标显隐开关、累计/单日切换、
/// 折线图（LineChartView）与四项汇总指标。
struct MonitorChartView: View {
    let task: ChartTask                            // 任务数据（Identifiable 包装的 J）
    var onClose: () -> Void                        // 返回回调

    @State private var metrics: [String: [(Date, Double)]] = [:]   // data_type → 点列（时间+值）
    @State private var loading = false             // 加载中
    @State private var error = ""                  // 错误文案
    @State private var cumulative = true           // true=累计曲线 / false=单日增量
    @State private var metric = "play_count"       // 当前选中指标（单选单线，对齐安卓 MonitorChartScreen）

    /// 指标定义：data_type / 中文名 / 折线色
    private let metricDefs: [(String, String, Color)] = [
        ("play_count", "播放", T.primary),         // 播放-青
        ("comment_count", "评论", T.warn),         // 评论-黄
        ("like_count", "点赞", T.secondary),       // 点赞-紫
        ("share_count", "分享", .green),           // 分享-绿
    ]

    var body: some View {
        ZStack {
            TechBackground()                       // 深空背景
            VStack(spacing: 0) {
                NavBar(title: "数据趋势", back: onClose)   // 顶栏
                ScrollView(showsIndicators: false) {       // 滚动区
                    VStack(alignment: .leading, spacing: 14) {
                        // 作品信息
                        GlassCard(padding: 14) {                   // 信息卡
                            HStack(spacing: 12) {                  // 封面+文字横排
                                // 封面：后端 gettasklist 返回字段 content_image（原 cover 不存在实证）
                                NetImage(url: task.j["content_image"].str, width: 46, height: 60)   // 封面图
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 4) {
                                    // 标题：后端字段 content_title（原 video_title 不存在实证）
                                    Text(task.j["content_title"].str ?? "未命名作品")          // 标题（两行截断）
                                        .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(2)
                                    let days = Fmt.daysLeft(task.j["expire_time"].str ?? task.j["end_time"].str ?? "")  // 剩余天数
                                    Text(days > 0 ? "监控中 · 剩余 \(days) 天" : "已到期停止采集")            // 状态文案
                                        .font(.system(size: 11)).foregroundColor(days > 0 ? .green : T.danger)  // 绿/红
                                }
                                Spacer()
                            }
                        }

                        // 指标切换（单选） + 累计切换
                        HStack(spacing: 8) {                       // 四胶囊+右侧切换
                            ForEach(metricDefs, id: \.0) { m in    // 遍历指标定义
                                Button {                           // 点按选中该指标（单线展示）
                                    metric = m.0
                                } label: {
                                    Text(m.1)                      // 指标名胶囊
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(metric == m.0 ? m.2 : T.textSub)                  // 选中本色/未选灰
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(metric == m.0 ? m.2.opacity(0.14) : Color.white.opacity(0.05)))  // 选中淡色底/未选淡灰
                                        .overlay(Capsule().stroke(metric == m.0 ? m.2.opacity(0.4) : T.stroke, lineWidth: 1))      // 描边同步
                                }
                            }
                            Spacer()                               // 右推
                            Button {                               // 累计/单日切换
                                cumulative.toggle()                // 翻转模式
                                load()                             // 重新拉数据
                            } label: {
                                Text(cumulative ? "累计" : "单日")  // 模式文案
                                    .font(.system(size: 12, weight: .medium)).foregroundColor(T.primary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(T.primary.opacity(0.12)))  // 青色淡底
                            }
                        }

                        // 折线图卡
                        GlassCard {                                // 图表卡
                            VStack(alignment: .leading, spacing: 10) {
                                if loading && metrics.isEmpty {    // 首次加载：
                                    ProgressView().tint(T.primary).frame(maxWidth: .infinity).padding(.vertical, 60)  // 居中转圈
                                } else if metrics.isEmpty {        // 无数据：
                                    EmptyState(icon: "chart.xyaxis.line", text: error.isEmpty ? "数据采集中，稍后再来看看" : error)  // 空态/错误
                                        .padding(.vertical, 20)
                                } else {                           // 有数据：
                                    let series = metricDefs.compactMap { m -> LineChartView.Series? in  // 组装序列（单选：仅当前指标）
                                        guard m.0 == metric, let pts = metrics[m.0], !pts.isEmpty else { return nil }  // 未选中或无点：跳过
                                        return LineChartView.Series(label: m.1, color: m.2, points: pts)  // 序列（元组隐式适配命名字段）
                                    }
                                    if series.isEmpty {            // 选中指标暂无数据：
                                        EmptyState(icon: "chart.xyaxis.line", text: "该指标暂无数据，稍后再来看看")
                                            .padding(.vertical, 20)
                                    } else {
                                        LineChartView(series: series)  // 折线图
                                    }
                                    // 汇总行
                                    let st = task.j["stats"].exists ? task.j["stats"] : task.j   // 统计节点（stats 优先，回退任务根）
                                    HStack {                       // 四指标等分
                                        MetricCell(value: (st["play"].dbl ?? st["play_count"].dbl ?? 0).numFmtCn2, label: "总播放", color: T.primary)      // 总播放
                                        MetricCell(value: (st["like"].dbl ?? st["like_count"].dbl ?? 0).numFmtCn2, label: "总点赞", color: T.secondary)    // 总点赞
                                        MetricCell(value: (st["comment"].dbl ?? st["comment_count"].dbl ?? 0).numFmtCn2, label: "总评论", color: T.warn)   // 总评论
                                        MetricCell(value: (st["share"].dbl ?? st["share_count"].dbl ?? 0).numFmtCn2, label: "总分享", color: .green)       // 总分享
                                    }
                                }
                            }
                        }

                        // 每日数据明细表（对齐安卓 MonitorChartScreen「每日明细」：日期倒序最新在上）
                        if !metrics.isEmpty {
                            GlassCard {                            // 表格卡
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("每日数据明细").font(.system(size: 14, weight: .semibold)).foregroundColor(T.textMain)  // 区块标题
                                    // 表头：日期+四指标列（列宽固定比例，与数据行对齐）
                                    dailyRow(date: "日期", vals: ["播放", "点赞", "评论", "分享"], header: true)
                                    ForEach(dailyRows.reversed(), id: \.0) { row in   // 倒序：最新日期在最上
                                        dailyRow(date: row.0, vals: row.1, header: false)  // 单日数据行
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)      // 左右留白
                    .padding(.bottom, 30)          // 底部留白
                }
            }
        }
        .onAppear { load() }                       // 进页拉数据
    }

    /// 拉取监控数据：monitor/get-data（daily 周期）→ 按 data_type 分组
    private func load() {
        loading = true                             // 进入加载态
        error = ""                                 // 清错误
        Task {                                     // 后台请求
            defer { loading = false }              // 退出加载态
            do {
                let d = try await Network.post("monitor/get-data", body: [
                    "user_email": SessionStore.email,                     // 账号标识
                    "task_id": task.j["task_id"].str ?? task.j["id"].str ?? "",  // 任务 ID（双字段兼容）
                    "period": "daily",                                    // 日粒度
                    "is_cumulative": cumulative,                          // 累计/单日
                ])
                // data[] 元素：{data_type, timestamp, value}
                var m: [String: [(Date, Double)]] = [:]                   // 分组容器
                for e in d.arr {                                          // 遍历数据点
                    guard let type = e["data_type"].str ?? e["metric"].str,      // 指标类型（双字段兼容）
                          let ts = Fmt.time(e["timestamp"].str ?? e["time"].str ?? ""),  // 时间（双字段兼容）
                          let v = e["value"].dbl else { continue }        // 值缺失：跳过
                    m[type, default: []].append((ts, v))                  // 追加到对应组
                }
                let snapshot = m                                          // let 快照（并发捕获要求）
                await MainActor.run { metrics = snapshot }                // 主线程提交
            } catch {                                                     // 失败：
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }  // 展示原因
            }
        }
    }

    /// 每日明细数据源：把四指标点列按「日」聚合 → [(日期"MM-dd", [四指标字符串])]
    /// daily 粒度每指标每天仅一点，聚合取当日最后一点（服务端多次采集时兜底）
    private var dailyRows: [(String, [String])] {
        let f = DateFormatter()                          // 日期格式化（线程内局部实例）
        f.dateFormat = "MM-dd"                           // 表格里只显示月-日
        var byDay: [String: [Double]] = [:]              // 日期 → 四指标值（顺序同 metricDefs）
        var order: [String] = []                         // 日期出现顺序（保持时间轴）
        for (mi, m) in metricDefs.enumerated() {         // 遍历四个指标
            for (d, v) in metrics[m.0] ?? [] {           // 该指标的每个数据点
                let day = f.string(from: d)              // 时间戳 → "MM-dd"
                if byDay[day] == nil {                   // 新日期：
                    byDay[day] = [0, 0, 0, 0]            // 四指标清零初始化
                    order.append(day)                    // 记录出现顺序
                }
                byDay[day]![mi] = v                      // 写入对应指标位（后写覆盖=当日最后一点）
            }
        }
        return order.map { day in                        // 按时间轴顺序组装行数据
            (day, byDay[day]!.map { $0.numFmtCn2 })      // (日期, [四指标格式化值])
        }
    }

    /// 每日明细单行：日期列 + 四指标数值列（表头/数据行共用布局）
    /// - Parameters:
    ///   - date: 日期列文字（表头传"日期"）
    ///   - vals: 四列数值/表头文字
    ///   - header: 是否表头行（表头用次级色小字，数据行用主色）
    private func dailyRow(date: String, vals: [String], header: Bool) -> some View {
        let dateF = f_dateCol                            // 日期列宽
        return HStack(spacing: 0) {                      // 五列横排
            Text(date)                                   // 日期列
                .font(.system(size: header ? 11 : 12, weight: header ? .regular : .medium))
                .foregroundColor(header ? T.textSub : T.textMain)
                .frame(width: dateF, alignment: .leading)
            ForEach(Array(vals.enumerated()), id: \.offset) { i, v in   // 四指标列
                Text(v)
                    .font(.system(size: header ? 11 : 12, weight: header ? .regular : .medium))
                    .foregroundColor(header ? T.textSub : metricDefs[i].2)  // 数值列用各指标本色（呼应折线图例）
                    .frame(maxWidth: .infinity, alignment: .center)          // 等宽居中
            }
        }
        .padding(.vertical, 4)                           // 行内上下留白
        .background(header ? AnyShapeStyle(Color.white.opacity(0.04)) : AnyShapeStyle(Color.clear))  // 表头淡底分隔
    }

    /// 日期列固定宽度（"MM-dd" 五字符）
    private var f_dateCol: CGFloat { 64 }
}

/// sheet(item:) 用 Identifiable 包装：任务 J 包一层 UUID
struct ChartTask: Identifiable {
    let id = UUID()   // 自动唯一 ID
    let j: J          // 原始任务数据
}
