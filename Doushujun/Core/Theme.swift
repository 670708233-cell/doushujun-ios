import SwiftUI

/// 科技风主题（对齐安卓 TechFx/Theme 配色）
enum T {
    static let bg = Color(hex: "060A13")            // 深空底
    static let card = Color(hex: "0D1420")          // 卡片底
    static let cardHi = Color(hex: "111B2E")        // 卡片高亮底
    static let stroke = Color.white.opacity(0.08)   // 描边
    static let primary = Color(hex: "00E5FF")       // 霓虹青
    static let secondary = Color(hex: "7C4DFF")     // 电紫
    static let success = Color(hex: "00E676")       // 成功绿
    static let danger = Color(hex: "FF5252")        // 危险红
    static let warn = Color(hex: "FFC107")          // 警告黄
    static let textMain = Color.white
    static let textSub = Color.white.opacity(0.55)

    /// 常用渐变（青→紫）
    static var grad: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 深空科技背景：渐变 + 顶部光晕 + 网格线（对齐安卓 TechBackground）
struct TechBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [T.bg, Color(hex: "0A1020")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [T.primary.opacity(0.10), .clear], center: .init(x: 0.2, y: 0.0), startRadius: 10, endRadius: 420)
            RadialGradient(colors: [T.secondary.opacity(0.10), .clear], center: .init(x: 0.9, y: 0.15), startRadius: 10, endRadius: 420)
            GeometryReader { g in
                Path { p in
                    let step: CGFloat = 44
                    var x: CGFloat = 0
                    while x <= g.size.width { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: g.size.height)); x += step }
                    var y: CGFloat = 0
                    while y <= g.size.height { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: g.size.width, y: y)); y += step }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

/// 玻璃质感卡片
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(T.card.opacity(0.88)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(T.stroke, lineWidth: 1))
    }
}

/// 区块标题（左侧竖条 + 文字）
struct SectionTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(T.grad).frame(width: 4, height: 16)
            Text(text).font(.system(size: 16, weight: .semibold)).foregroundColor(T.textMain)
        }
    }
}

/// 主按钮（渐变底、loading 态）
struct PrimaryButton: View {
    let title: String
    var loading = false
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button {
            if !loading && enabled { action() }
        } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white) }
                Text(loading ? "处理中…" : title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(T.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(enabled && !loading ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.12)))
            )
        }
        .disabled(!enabled || loading)
    }
}

/// 输入框（深色胶囊 + 青色聚焦描边）
struct DSJField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .font(.system(size: 15))
        .foregroundColor(T.textMain)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.stroke, lineWidth: 1))
    }
}

/// 空状态
struct EmptyState: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(T.textSub)
            Text(text).font(.system(size: 14)).foregroundColor(T.textSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

/// 错误红字行
struct ErrorText: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            Text(text).font(.system(size: 13)).foregroundColor(T.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 配额行（今日已用/上限）
struct QuotaRow: View {
    var body: some View {
        let bus = SessionBus.shared
        HStack {
            Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundColor(T.warn)
            Text("今日已用 \(bus.usedToday)/\(bus.dailyLimit <= 0 ? "∞" : String(bus.dailyLimit))")
                .font(.system(size: 12)).foregroundColor(T.textSub)
            Spacer()
            Text("余额 \(String(format: "%.2f", bus.balance))")
                .font(.system(size: 12)).foregroundColor(T.primary)
        }
    }
}

/// 全屏 loading 遮罩
struct FullLoading: View {
    let text: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.4).tint(T.primary)
                Text(text).font(.system(size: 14)).foregroundColor(T.textMain)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.stroke, lineWidth: 1))
        }
    }
}

/// 通用 Toast 宿主（挂在根视图）
struct ToastHost: View {
    @ObservedObject var bus = SessionBus.shared
    var body: some View {
        VStack {
            if let msg = bus.toast {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .overlay(Capsule().stroke(T.stroke, lineWidth: 1))
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { bus.toast = nil }
                    .task {
                        try? await Task.sleep(nanoseconds: 3_200_000_000)
                        withAnimation { bus.toast = nil }
                    }
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: bus.toast)
        .allowsHitTesting(bus.toast != nil)
    }
}

/// 自定义返回导航条（统一顶栏）
struct NavBar: View {
    let title: String
    var back: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(action: back) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                    .foregroundColor(T.textMain).frame(width: 40, height: 40)
            }
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(T.textMain)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

/// 信息行（标签: 值，带提示）
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = T.textMain
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 13)).foregroundColor(T.textSub)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 13)).foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }
}

/// 数字指标块（竖排：值+标签）
struct MetricCell: View {
    let value: String
    let label: String
    var color: Color = T.textMain
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(T.textSub)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 时间戳格式化（秒/毫秒自动识别 + 字符串日期兼容）
enum Fmt {
    static func time(_ raw: String?) -> Date? {
        guard var s = raw, !s.isEmpty else { return nil }
        if let d = Double(s) {
            let ts = d > 1e12 ? d / 1000 : d   // 毫秒→秒
            return Date(timeIntervalSince1970: ts)
        }
        s = s.replacingOccurrences(of: "T", with: " ")
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        if let d = f.date(from: s) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    static func mdhm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    static func full(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    /// 剩余天数（监控任务）
    static func daysLeft(_ end: String) -> Int {
        guard let d = time(end) else { return 0 }
        return max(0, Int(ceil(d.timeIntervalSinceNow / 86400)))
    }
}
