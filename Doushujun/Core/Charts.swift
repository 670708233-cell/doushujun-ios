import SwiftUI

/// 折线图（对齐安卓 LineChart：多序列、5 网格、底部时间轴、触点高亮）
struct LineChartView: View {
    struct Series {
        let label: String
        let color: Color
        let points: [(t: Date, v: Double)]
    }

    let series: [Series]
    var showLegend = true

    var body: some View {
        GeometryReader { g in
            let left: CGFloat = 46, bottom: CGFloat = 26, top: CGFloat = 10, right: CGFloat = 8
            let w = g.size.width - left - right
            let h = g.size.height - top - bottom
            let all = series.flatMap { $0.points.map(\.v) }
            let maxV = max(all.max() ?? 1, 1)
            let minV = min(all.min() ?? 0, 0)
            let span = maxV - minV == 0 ? 1 : maxV - minV
            let allDates = series.flatMap { $0.points.map(\.t) }.sorted()
            let t0 = allDates.first ?? Date()
            let t1 = max(allDates.last ?? Date().addingTimeInterval(1), t0.addingTimeInterval(1))

            func pos(_ p: (t: Date, v: Double)) -> CGPoint {
                let fx = p.t.timeIntervalSince(t0) / t1.timeIntervalSince(t0)
                let fy = (p.v - minV) / span
                return CGPoint(x: left + fx * w, y: top + (1 - fy) * h)
            }

            ZStack {
                // 横向网格 5 条 + Y 轴刻度
                ForEach(0..<5, id: \.self) { i in
                    let f = CGFloat(i) / 4
                    let y = top + f * h
                    Path { p in
                        p.move(to: CGPoint(x: left, y: y))
                        p.addLine(to: CGPoint(x: left + w, y: y))
                    }
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    let val = maxV - f * span
                    Text(shortNum(val))
                        .font(.system(size: 9)).foregroundColor(T.textSub)
                        .position(x: left - 4, y: y)
                        .frame(maxWidth: left - 6, alignment: .trailing)
                }
                // X 轴首尾时间
                if let d0 = allDates.first, let d1 = allDates.last {
                    Text(Fmt.mdhm(d0)).font(.system(size: 9)).foregroundColor(T.textSub)
                        .position(x: left + 20, y: top + h + 12)
                    Text(Fmt.mdhm(d1)).font(.system(size: 9)).foregroundColor(T.textSub)
                        .position(x: left + w - 20, y: top + h + 12)
                }
                // 各序列折线
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    let pts = s.points.sorted { $0.t < $1.t }.map(pos)
                    if pts.count >= 2 {
                        Path { p in
                            p.move(to: pts[0])
                            for pt in pts.dropFirst() { p.addLine(to: pt) }
                        }
                        .stroke(s.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    if pts.count == 1 {
                        Circle().fill(s.color).frame(width: 6, height: 6).position(pts[0])
                    }
                    // 数据点
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(s.color).frame(width: 4, height: 4).position(pt)
                    }
                }
            }
        }
        .frame(height: 210)
        .overlay(alignment: .topTrailing) {
            if showLegend && series.count > 1 {
                HStack(spacing: 10) {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 4) {
                            Circle().fill(s.color).frame(width: 7, height: 7)
                            Text(s.label).font(.system(size: 10)).foregroundColor(T.textSub)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private func shortNum(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1e8 { return String(format: "%.0f亿", v / 1e8) }
        if a >= 1e4 { return String(format: "%.0f万", v / 1e4) }
        if v >= 1000 || v == 0 { return String(Int(v)) }
        return String(format: "%.0f", v)
    }
}

/// 雷达图（作品互动率 5 维：点赞/评论/转发/收藏/关注率，0-100）
struct RadarChartView: View {
    /// 5 维值 0~100
    let values: [Double]
    let labels: [String]

    var body: some View {
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let r = min(g.size.width, g.size.height) / 2 - 26
            ZStack {
                // 3 层网格多边形
                ForEach([1.0, 0.66, 0.33], id: \.self) { f in
                    Path { p in
                        poly(center: c, radius: r * f).forEach {
                            if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                        }
                        p.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                // 轴线
                ForEach(0..<max(labels.count, 1), id: \.self) { i in
                    Path { p in
                        p.move(to: c)
                        p.addLine(to: anglePoint(center: c, radius: r, index: i, total: labels.count))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                // 数据多边形
                if values.count == labels.count {
                    let dpts = dataPts(center: c, radius: r)
                    Path { p in
                        dpts.forEach {
                            if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                        }
                        p.closeSubpath()
                    }
                    .fill(T.primary.opacity(0.22))
                    .overlay(
                        Path { p in
                            dpts.forEach {
                                if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                            }
                            p.closeSubpath()
                        }
                        .stroke(T.primary, lineWidth: 2)
                    )
                    ForEach(Array(dpts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(T.primary).frame(width: 5, height: 5).position(pt)
                    }
                }
                // 标签
                ForEach(Array(labels.enumerated()), id: \.offset) { i, lb in
                    let pt = anglePoint(center: c, radius: r + 14, index: i, total: labels.count)
                    Text(lb).font(.system(size: 10)).foregroundColor(T.textSub)
                        .position(pt)
                }
            }
        }
        .frame(height: 190)
    }

    private func poly(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<labels.count).map { anglePoint(center: center, radius: radius, index: $0, total: labels.count) }
    }

    private func anglePoint(center: CGPoint, radius: CGFloat, index: Int, total: Int) -> CGPoint {
        let ang = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(max(total, 1))
        return CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius)
    }
}

/// 数据多边形点必须与外层几何一致；简化版直接内联绘制
extension RadarChartView {
    fileprivate func dataPts(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<labels.count).map { i in
            let v = i < values.count ? max(0, min(100, values[i])) / 100 : 0
            let ang = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(max(labels.count, 1))
            return CGPoint(x: center.x + cos(ang) * radius * CGFloat(v), y: center.y + sin(ang) * radius * CGFloat(v))
        }
    }
}
