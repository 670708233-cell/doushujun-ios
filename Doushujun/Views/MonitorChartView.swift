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
    @State private var hidden: Set<String> = []    // 被隐藏的指标集合（最多隐 3 个）

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
                                NetImage(url: task.j["cover"].str, width: 46, height: 60)   // 封面图
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.j["video_title"].str ?? "未命名作品")          // 标题（两行截断）
                                        .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(2)
                                    let days = Fmt.daysLeft(task.j["expire_time"].str ?? task.j["end_time"].str ?? "")  // 剩余天数
                                    Text(days > 0 ? "监控中 · 剩余 \(days) 天" : "已到期停止采集")            // 状态文案
                                        .font(.system(size: 11)).foregroundColor(days > 0 ? .green : T.danger)  // 绿/红
                                }
                                Spacer()
                            }
                        }

                        // 指标开关 + 累计切换
                        HStack(spacing: 8) {                       // 四胶囊+右侧切换
                            ForEach(metricDefs, id: \.0) { m in    // 遍历指标定义
                                Button {                           // 点按切换显隐
                                    if hidden.contains(m.0) { hidden.remove(m.0) } else if hidden.count < 3 { hidden.insert(m.0) }  // 最多同时隐 3 个（至少留 1 条线）
                                } label: {
                                    Text(m.1)                      // 指标名胶囊
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(hidden.contains(m.0) ? T.textSub : m.2)                       // 隐藏灰/显示本色
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(hidden.contains(m.0) ? Color.white.opacity(0.05) : m.2.opacity(0.14)))  // 隐藏淡灰/显示淡色底
                                        .overlay(Capsule().stroke(hidden.contains(m.0) ? T.stroke : m.2.opacity(0.4), lineWidth: 1))       // 描边同步
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
                                    let series = metricDefs.compactMap { m -> LineChartView.Series? in  // 组装可见序列
                                        guard let pts = metrics[m.0], !pts.isEmpty, !hidden.contains(m.0) else { return nil }  // 无点或被隐藏：跳过
                                        return LineChartView.Series(label: m.1, color: m.2, points: pts)  // 序列（元组隐式适配命名字段）
                                    }
                                    if series.isEmpty {            // 全被隐藏：
                                        Text("请至少选择一个指标").font(.system(size: 13)).foregroundColor(T.textSub)
                                            .frame(maxWidth: .infinity).padding(.vertical, 40)  // 提示
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
}

/// sheet(item:) 用 Identifiable 包装：任务 J 包一层 UUID
struct ChartTask: Identifiable {
    let id = UUID()   // 自动唯一 ID
    let j: J          // 原始任务数据
}
