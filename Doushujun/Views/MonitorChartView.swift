import SwiftUI

/// 监控趋势图（对齐安卓 MonitorChartScreen：4 指标折线 + 累计切换）
struct MonitorChartView: View {
    let task: ChartTask
    var onClose: () -> Void

    @State private var metrics: [String: [(Date, Double)]] = [:]   // data_type → 点列
    @State private var loading = false
    @State private var error = ""
    @State private var cumulative = true
    @State private var hidden: Set<String> = []

    private let metricDefs: [(String, String, Color)] = [
        ("play_count", "播放", T.primary),
        ("comment_count", "评论", T.warn),
        ("like_count", "点赞", T.secondary),
        ("share_count", "分享", .green),
    ]

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "数据趋势", back: onClose)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 作品信息
                        GlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                NetImage(url: task.j["cover"].str, width: 46, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.j["video_title"].str ?? "未命名作品")
                                        .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(2)
                                    let days = Fmt.daysLeft(task.j["expire_time"].str ?? task.j["end_time"].str ?? "")
                                    Text(days > 0 ? "监控中 · 剩余 \(days) 天" : "已到期停止采集")
                                        .font(.system(size: 11)).foregroundColor(days > 0 ? .green : T.danger)
                                }
                                Spacer()
                            }
                        }

                        // 指标开关 + 累计切换
                        HStack(spacing: 8) {
                            ForEach(metricDefs, id: \.0) { m in
                                Button {
                                    if hidden.contains(m.0) { hidden.remove(m.0) } else if hidden.count < 3 { hidden.insert(m.0) }
                                } label: {
                                    Text(m.1)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(hidden.contains(m.0) ? T.textSub : m.2)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(hidden.contains(m.0) ? Color.white.opacity(0.05) : m.2.opacity(0.14)))
                                        .overlay(Capsule().stroke(hidden.contains(m.0) ? T.stroke : m.2.opacity(0.4), lineWidth: 1))
                                }
                            }
                            Spacer()
                            Button {
                                cumulative.toggle()
                                load()
                            } label: {
                                Text(cumulative ? "累计" : "单日")
                                    .font(.system(size: 12, weight: .medium)).foregroundColor(T.primary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(T.primary.opacity(0.12)))
                            }
                        }

                        // 折线图卡
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                if loading && metrics.isEmpty {
                                    ProgressView().tint(T.primary).frame(maxWidth: .infinity).padding(.vertical, 60)
                                } else if metrics.isEmpty {
                                    EmptyState(icon: "chart.xyaxis.line", text: error.isEmpty ? "数据采集中，稍后再来看看" : error)
                                        .padding(.vertical, 20)
                                } else {
                                    let series = metricDefs.compactMap { m -> LineChartView.Series? in
                                        guard let pts = metrics[m.0], !pts.isEmpty, !hidden.contains(m.0) else { return nil }
                                        return LineChartView.Series(label: m.1, color: m.2, points: pts)
                                    }
                                    if series.isEmpty {
                                        Text("请至少选择一个指标").font(.system(size: 13)).foregroundColor(T.textSub)
                                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                                    } else {
                                        LineChartView(series: series)
                                    }
                                    // 汇总行
                                    let st = task.j["stats"].exists ? task.j["stats"] : task
                                    HStack {
                                        MetricCell(value: (st["play"].dbl ?? st["play_count"].dbl ?? 0).numFmtCn2, label: "总播放", color: T.primary)
                                        MetricCell(value: (st["like"].dbl ?? st["like_count"].dbl ?? 0).numFmtCn2, label: "总点赞", color: T.secondary)
                                        MetricCell(value: (st["comment"].dbl ?? st["comment_count"].dbl ?? 0).numFmtCn2, label: "总评论", color: T.warn)
                                        MetricCell(value: (st["share"].dbl ?? st["share_count"].dbl ?? 0).numFmtCn2, label: "总分享", color: .green)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("monitor/get-data", body: [
                    "user_email": SessionStore.email,
                    "task_id": task.j["task_id"].str ?? task.j["id"].str ?? "",
                    "period": "daily",
                    "is_cumulative": cumulative,
                ])
                // data[] 元素：{data_type, timestamp, value}
                var m: [String: [(Date, Double)]] = [:]
                for e in d.arr {
                    guard let type = e["data_type"].str ?? e["metric"].str,
                          let ts = Fmt.time(e["timestamp"].str ?? e["time"].str ?? ""),
                          let v = e["value"].dbl else { continue }
                    m[type, default: []].append((ts, v))
                }
                await MainActor.run { metrics = m }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }
}

/// sheet(item:) 用 Identifiable 包装
struct ChartTask: Identifiable {
    let id = UUID()
    let j: J
}
