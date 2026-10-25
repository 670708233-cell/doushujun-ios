import SwiftUI  // UI 框架：Canvas/Path/GeometryReader

/// 折线图（对齐安卓 LineChart：单线、niceCeil 刻度顶、0 基线、5 网格、
/// Y 轴刻度文字、底部首/中/尾 3 个 X 轴日期、贝塞尔平滑曲线）：
/// 纯 SwiftUI Path 自绘——监控页趋势展示，无第三方图表依赖。
struct LineChartView: View {
    /// 折线序列：名称/颜色/数据点（时间+值）
    struct Series {
        let label: String                      // 图例名称（如 播放）
        let color: Color                       // 线色
        let points: [(t: Date, v: Double)]     // 数据点（命名元组）
    }

    let series: [Series]          // 全部序列（对齐安卓为单选单线，通常仅 1 条）

    var body: some View {
        GeometryReader { g in     // 几何读取：按容器尺寸自绘
            // ---- 布局常量：左留白放 Y 轴刻度，下留白放 X 轴日期 ----
            let left: CGFloat = 46, bottom: CGFloat = 24, top: CGFloat = 8, right: CGFloat = 10
            let w = g.size.width - left - right   // 绘图区宽
            let h = g.size.height - top - bottom  // 绘图区高
            let all = series.flatMap { $0.points }             // 全部数据点（跨序列）
            let maxV = Self.niceCeil(all.map(\.v).max() ?? 1)  // 刻度顶：最大值向上取到 0.5×10^n 倍数（对齐安卓 niceCeil）
            let allDates = all.map(\.t).sorted()               // 全部时间升序
            let t0 = allDates.first ?? Date()     // 时间轴起点
            let t1 = max(allDates.last ?? Date().addingTimeInterval(1), t0.addingTimeInterval(1))  // 终点（防零跨度）
            let span = t1.timeIntervalSince(t0)   // 时间跨度

            // 数据点→画布坐标：x 按时间线性映射；y 按 0~maxV 线性映射（0 基线，对齐安卓 py）
            let px: (Date) -> CGFloat = { left + CGFloat($0.timeIntervalSince(t0) / span) * w }
            let py: (Double) -> CGFloat = { top + (1 - CGFloat($0 / maxV)) * h }

            ZStack {
                // 横向网格 5 条 + Y 轴刻度（顶=刻度顶，底=0）
                ForEach(0..<5, id: \.self) { i in
                    let y = top + CGFloat(i) / 4 * h        // 网格线 y（i=0 顶 → i=4 底）
                    let val = maxV * Double(4 - i) / 4      // 该刻度对应数值（上大下小）
                    Path { p in                             // 画横线
                        p.move(to: CGPoint(x: left, y: y))
                        p.addLine(to: CGPoint(x: left + w, y: y))
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)  // 淡白细线
                    Text(Self.shortNum(val))                // 万/亿缩写刻度
                        .font(.system(size: 9)).foregroundColor(T.textSub)
                        .position(x: left - 4, y: y)        // 贴左轴
                        .frame(maxWidth: left - 6, alignment: .trailing)  // 右对齐
                }
                // X 轴日期：首/中/尾 3 个标签，中心对齐画在对应数据点的 x 上（对齐安卓 fmtDate 三点）
                if let d0 = allDates.first, let d1 = allDates.last {
                    let mid = allDates[allDates.count / 2]  // 中点数据的时间
                    ForEach([d0, mid, d1], id: \.self) { d in
                        Text(Self.axisDate(d)).font(.system(size: 9)).foregroundColor(T.textSub)
                            .position(x: px(d), y: top + h + 12)   // 画在对应 x、绘图区下方
                    }
                }
                // 各序列折线（贝塞尔平滑：控制点取相邻两点水平中点 → S 形过渡，对齐安卓 smooth）
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    let pts = s.points.sorted { $0.t < $1.t }       // 按时间排序
                    if pts.count >= 2 {                             // ≥2 点：画平滑折线
                        let xy = pts.map { CGPoint(x: px($0.t), y: py($0.v)) }  // 转画布坐标
                        Path { p in
                            p.move(to: xy[0])                       // 起笔
                            if xy.count > 2 {                       // ≥3 点：三次贝塞尔平滑
                                for i in 1..<xy.count {
                                    let a = xy[i - 1], b = xy[i]    // 相邻两点
                                    let midX = (a.x + b.x) / 2      // 水平中点
                                    p.addCurve(to: b, control1: CGPoint(x: midX, y: a.y), control2: CGPoint(x: midX, y: b.y))
                                }
                            } else {                                // 恰 2 点：直线段
                                p.addLine(to: xy[1])
                            }
                        }
                        .stroke(s.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))  // 圆头圆角
                        ForEach(Array(xy.enumerated()), id: \.offset) { _, pt in
                            Circle().fill(s.color).frame(width: 4, height: 4).position(pt)  // 数据点小圆
                        }
                    }
                    if let only = pts.first, pts.count == 1 {       // 单点：画一个大圆点
                        Circle().fill(s.color).frame(width: 6, height: 6).position(x: px(only.t), y: py(only.v))
                    }
                }
            }
        }
        .frame(height: 210)                                 // 固定图高
    }

    /// 取整到好看的刻度顶：最大值向上取到 0.5×10^n 的整数倍（37→50，8200→10000，对齐安卓 niceCeil）
    private static func niceCeil(_ v: Double) -> Double {
        guard v > 0 else { return 1 }                       // 非正数兜底为 1
        let exp = floor(log10(v))                           // 数量级 10^n 的 n
        let base = pow(10, exp)                             // 数量级基数
        return (v / (base / 2)).rounded(.up) * (base / 2)   // 按 0.5×10^n 步长向上取整
    }

    /// Y 轴刻度缩写：亿/万/整数（对齐安卓 shortNum）
    private static func shortNum(_ v: Double) -> String {
        let a = abs(v)                                          // 绝对值判量级
        if a >= 1e8 { return String(format: "%.1f亿", v / 1e8) }   // ≥1亿：一位小数
        if a >= 1e4 {                                           // ≥1万：整万不带小数
            return v.truncatingRemainder(dividingBy: 1e4) == 0 ? "\(Int(v / 1e4))万" : String(format: "%.1f万", v / 1e4)
        }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)  // 整数/一位小数
    }

    /// X 轴日期格式："M/d" 短格式（对齐安卓 fmtDate，如 10/19）
    private static func axisDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
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
