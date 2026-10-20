import SwiftUI  // UI 框架：Canvas/Path/GeometryReader

/// 折线图（对齐安卓 LineChart：多序列、5 网格、底部时间轴、触点高亮）：
/// 纯 SwiftUI Path 自绘——监控页多指标趋势展示，无第三方图表依赖。
struct LineChartView: View {
    /// 折线序列：名称/颜色/数据点（时间+值）
    struct Series {
        let label: String                      // 图例名称（如 播放）
        let color: Color                       // 线色
        let points: [(t: Date, v: Double)]     // 数据点（命名元组）
    }

    let series: [Series]          // 全部序列
    var showLegend = true         // 是否显示图例（多序列时有意义）

    var body: some View {
        GeometryReader { g in     // 几何读取：按容器尺寸自绘
            // ---- 布局常量：左留白放 Y 轴刻度，下留白放时间轴 ----
            let left: CGFloat = 46, bottom: CGFloat = 26, top: CGFloat = 10, right: CGFloat = 8
            let w = g.size.width - left - right   // 绘图区宽
            let h = g.size.height - top - bottom  // 绘图区高
            let all = series.flatMap { $0.points.map(\.v) }   // 全部值（跨序列）
            let maxV = max(all.max() ?? 1, 1)     // 值域上界（至少 1，防除零）
            let minV = min(all.min() ?? 0, 0)     // 值域下界（至少 0）
            let span = maxV - minV == 0 ? 1 : maxV - minV     // 值域跨度（防零）
            let allDates = series.flatMap { $0.points.map(\.t) }.sorted()  // 全部时间升序
            let t0 = allDates.first ?? Date()     // 时间轴起点
            let t1 = max(allDates.last ?? Date().addingTimeInterval(1), t0.addingTimeInterval(1))  // 终点（防零跨度）

            // 数据点→画布坐标：x 按时间线性映射，y 按值反向映射（上大下小）
            let pos: ((t: Date, v: Double)) -> CGPoint = { p in
                let fx = p.t.timeIntervalSince(t0) / t1.timeIntervalSince(t0)  // 时间归一化 0~1
                let fy = (p.v - minV) / span                                   // 值归一化 0~1
                return CGPoint(x: left + fx * w, y: top + (1 - fy) * h)        // 画布坐标
            }

            ZStack {
                // 横向网格 5 条 + Y 轴刻度
                ForEach(0..<5, id: \.self) { i in
                    let f = CGFloat(i) / 4                  // 归一化位置 0~1
                    let y = top + f * h                     // 网格线 y
                    Path { p in                             // 画横线
                        p.move(to: CGPoint(x: left, y: y))
                        p.addLine(to: CGPoint(x: left + w, y: y))
                    }
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)  // 淡白细线
                    let val = maxV - f * span               // 该刻度对应数值（上大下小）
                    Text(shortNum(val))                     // 万/亿缩写刻度
                        .font(.system(size: 9)).foregroundColor(T.textSub)
                        .position(x: left - 4, y: y)        // 贴左轴
                        .frame(maxWidth: left - 6, alignment: .trailing)  // 右对齐
                }
                // X 轴首尾时间
                if let d0 = allDates.first, let d1 = allDates.last {
                    Text(Fmt.mdhm(d0)).font(.system(size: 9)).foregroundColor(T.textSub)   // 起始时间
                        .position(x: left + 20, y: top + h + 12)
                    Text(Fmt.mdhm(d1)).font(.system(size: 9)).foregroundColor(T.textSub)   // 结束时间
                        .position(x: left + w - 20, y: top + h + 12)
                }
                // 各序列折线
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    let pts = s.points.sorted { $0.t < $1.t }.map { pos($0) }  // 按时间排序后转坐标
                    if pts.count >= 2 {                     // ≥2 点：画折线
                        Path { p in
                            p.move(to: pts[0])              // 起笔
                            for pt in pts.dropFirst() { p.addLine(to: pt) }  // 依次连线
                        }
                        .stroke(s.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))  // 2px 圆头圆角
                    }
                    if pts.count == 1 {                     // 单点：画一个大圆点
                        Circle().fill(s.color).frame(width: 6, height: 6).position(pts[0])
                    }
                    // 数据点
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(s.color).frame(width: 4, height: 4).position(pt)  // 每点小圆
                    }
                }
            }
        }
        .frame(height: 210)                                 // 固定图高
        .overlay(alignment: .topTrailing) {                 // 右上角图例
            if showLegend && series.count > 1 {             // 多序列才显示
                HStack(spacing: 10) {                       // 图例横排
                    ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 4) {                // 色点+名称
                            Circle().fill(s.color).frame(width: 7, height: 7)
                            Text(s.label).font(.system(size: 10)).foregroundColor(T.textSub)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    /// Y 轴刻度缩写：亿/万/整数
    private func shortNum(_ v: Double) -> String {
        let a = abs(v)                                          // 绝对值判量级
        if a >= 1e8 { return String(format: "%.0f亿", v / 1e8) }  // ≥1亿
        if a >= 1e4 { return String(format: "%.0f万", v / 1e4) }  // ≥1万
        if v >= 1000 || v == 0 { return String(Int(v)) }        // 大整数/零
        return String(format: "%.0f", v)                        // 一位内小数取整
    }
}

/// 雷达图（作品互动率 5 维：点赞/评论/转发/收藏/关注率，0-100）：
/// 纯 Path 自绘——3 层网格多边形 + 轴线 + 数据区填充 + 顶点圆点 + 外圈标签。
struct RadarChartView: View {
    /// 5 维值 0~100
    let values: [Double]    // 各维数值（与 labels 一一对应）
    let labels: [String]    // 各维名称

    var body: some View {
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)   // 圆心=容器中心
            let r = min(g.size.width, g.size.height) / 2 - 26            // 半径（留标签边距）
            ZStack {
                // 3 层网格多边形
                ForEach([1.0, 0.66, 0.33], id: \.self) { f in   // 100%/66%/33% 三档
                    Path { p in
                        poly(center: c, radius: r * f).forEach {  // 顶点依次连线
                            if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                        }
                        p.closeSubpath()                       // 闭合
                    }
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)  // 淡白描边
                }
                // 轴线
                ForEach(0..<max(labels.count, 1), id: \.self) { i in  // 每维一条
                    Path { p in
                        p.move(to: c)                          // 从圆心出发
                        p.addLine(to: anglePoint(center: c, radius: r, index: i, total: labels.count))  // 到外圈顶点
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                // 数据多边形
                if values.count == labels.count {              // 维度对齐才绘制
                    let dpts = dataPts(center: c, radius: r)   // 数据顶点（值缩放半径）
                    Path { p in
                        dpts.forEach {                         // 依次连线闭合
                            if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                        }
                        p.closeSubpath()
                    }
                    .fill(T.primary.opacity(0.22))             // 品牌色淡填充
                    .overlay(                                  // 同形状描边
                        Path { p in
                            dpts.forEach {
                                if p.isEmpty { p.move(to: $0) } else { p.addLine(to: $0) }
                            }
                            p.closeSubpath()
                        }
                        .stroke(T.primary, lineWidth: 2)       // 2px 品牌色边
                    )
                    ForEach(Array(dpts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(T.primary).frame(width: 5, height: 5).position(pt)  // 顶点圆点
                    }
                }
                // 标签
                ForEach(Array(labels.enumerated()), id: \.offset) { i, lb in
                    let pt = anglePoint(center: c, radius: r + 14, index: i, total: labels.count)  // 外圈+14 处
                    Text(lb).font(.system(size: 10)).foregroundColor(T.textSub)
                        .position(pt)
                }
            }
        }
        .frame(height: 190)                                    // 固定图高
    }

    /// 正多边形顶点序列（网格用）
    private func poly(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<labels.count).map { anglePoint(center: center, radius: radius, index: $0, total: labels.count) }
    }

    /// 极坐标→直角坐标：从正上方（-90°）起顺时针均分
    private func anglePoint(center: CGPoint, radius: CGFloat, index: Int, total: Int) -> CGPoint {
        let ang = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(max(total, 1))  // 角度（防除零）
        return CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius)  // 三角函数定位
    }
}

/// 数据多边形点必须与外层几何一致；简化版直接内联绘制
extension RadarChartView {
    /// 数据顶点：每维值钳到 0~100 后按比例缩放半径
    fileprivate func dataPts(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0..<labels.count).map { i in
            let v = i < values.count ? max(0, min(100, values[i])) / 100 : 0  // 钳位归一化
            let ang = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(max(labels.count, 1))  // 同款角度公式
            return CGPoint(x: center.x + cos(ang) * radius * CGFloat(v), y: center.y + sin(ang) * radius * CGFloat(v))  // 半径×值比例
        }
    }
}
