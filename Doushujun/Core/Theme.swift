import SwiftUI  // UI 框架：Color/View/Path

/// 科技风主题（对齐安卓 TechFx/Theme 配色）：
/// 全局色板命名空间 T——所有视图统一从此取色，保证深空科技风一致。
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
    static let textMain = Color.white               // 主文字（白）
    static let textSub = Color.white.opacity(0.55)  // 次文字（半透明白）

    /// 常用渐变（青→紫）
    static var grad: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)  // 左上→右下
    }
}

extension Color {
    /// hex 字符串构造（"RRGGBB" 或 "#RRGGBB"）
    init(hex: String) {
        var v: UInt64 = 0                                                        // 解析结果容器
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)  // 去 # 后按 16 进制扫描
        self.init(                                                               // 拆 R/G/B 三字节归一化
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,    // 高 8 位：红
            green: Double((v >> 8) & 0xFF) / 255,   // 中 8 位：绿
            blue: Double(v & 0xFF) / 255,           // 低 8 位：蓝
            opacity: 1                              // 不透明
        )
    }
}

/// 深空科技背景：渐变 + 顶部光晕 + 网格线（对齐安卓 TechBackground）
struct TechBackground: View {
    var body: some View {
        ZStack {  // 四层叠加
            LinearGradient(colors: [T.bg, Color(hex: "0A1020")], startPoint: .top, endPoint: .bottom)  // 层1：上→下深空渐变
            RadialGradient(colors: [T.primary.opacity(0.10), .clear], center: .init(x: 0.2, y: 0.0), startRadius: 10, endRadius: 420)   // 层2：左上青色光晕
            RadialGradient(colors: [T.secondary.opacity(0.10), .clear], center: .init(x: 0.9, y: 0.15), startRadius: 10, endRadius: 420) // 层3：右上紫色光晕
            GeometryReader { g in                  // 层4：网格线（需容器尺寸）
                Path { p in
                    let step: CGFloat = 44         // 网格间距 44pt
                    var x: CGFloat = 0
                    while x <= g.size.width { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: g.size.height)); x += step }  // 竖线从左到右
                    var y: CGFloat = 0
                    while y <= g.size.height { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: g.size.width, y: y)); y += step }  // 横线从上到下
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 1)  // 极淡白线
            }
        }
        .ignoresSafeArea()  // 延伸到安全区外（全屏背景）
    }
}

/// 玻璃质感卡片：内容 + 圆角半透明底 + 细描边
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16            // 内边距（默认 16）
    @ViewBuilder var content: Content    // 卡片内容（ViewBuilder 闭包）

    var body: some View {
        content
            .padding(padding)                                                    // 内边距
            .frame(maxWidth: .infinity, alignment: .leading)                     // 撑满宽、左对齐
            .background(RoundedRectangle(cornerRadius: 18).fill(T.card.opacity(0.88)))  // 88% 卡片底
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(T.stroke, lineWidth: 1)) // 细描边
    }
}

/// 区块标题（左侧竖条 + 文字）
struct SectionTitle: View {
    let text: String               // 标题文本
    var body: some View {
        HStack(spacing: 8) {       // 竖条+文字横排
            RoundedRectangle(cornerRadius: 2).fill(T.grad).frame(width: 4, height: 16)  // 渐变竖条
            Text(text).font(.system(size: 16, weight: .semibold)).foregroundColor(T.textMain)  // 标题
        }
    }
}

/// 主按钮（渐变底、loading 态）
struct PrimaryButton: View {
    let title: String           // 按钮文案
    var loading = false         // 加载中（转圈+禁用）
    var enabled = true          // 可用开关
    var action: () -> Void      // 点击回调

    var body: some View {
        Button {
            if !loading && enabled { action() }  // 双重条件拦截点击
        } label: {
            HStack(spacing: 8) {                                       // 转圈+文字
                if loading { ProgressView().tint(.white) }             // 加载中显示白转圈
                Text(loading ? "处理中…" : title).font(.system(size: 16, weight: .semibold))  // 文案切换
            }
            .foregroundColor(T.bg)                     // 深色文字（衬渐变底）
            .frame(maxWidth: .infinity)                // 撑满宽
            .frame(height: 50)                         // 高 50
            .background(
                RoundedRectangle(cornerRadius: 14)     // 14 圆角底
                    .fill(enabled && !loading ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.12)))  // 可用渐变/禁用灰
            )
        }
        .disabled(!enabled || loading)                 // 系统级禁用
    }
}

/// 输入框（深色胶囊 + 青色聚焦描边）
struct DSJField: View {
    let placeholder: String                     // 占位文案
    @Binding var text: String                   // 输入绑定
    var secure = false                          // 密文模式（密码）
    var keyboard: UIKeyboardType = .default     // 键盘类型

    var body: some View {
        Group {
            if secure {                                     // 密文：
                SecureField(placeholder, text: $text)       // 圆点掩码输入
            } else {                                        // 明文：
                TextField(placeholder, text: $text)         // 普通输入
                    .keyboardType(keyboard)                 // 键盘类型
                    .autocapitalization(.none)              // 关首字母大写
                    .disableAutocorrection(true)            // 关自动纠错（账号输入）
            }
        }
        .font(.system(size: 15))                                                   // 字号
        .foregroundColor(T.textMain)                                               // 白字
        .padding(.horizontal, 14)                                                  // 左右内边距
        .frame(height: 48)                                                         // 高 48
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))  // 淡白底
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.stroke, lineWidth: 1))      // 细描边
    }
}

/// 空状态：大图标+提示文字居中
struct EmptyState: View {
    let icon: String              // SF Symbol 名
    let text: String              // 提示文案
    var body: some View {
        VStack(spacing: 12) {     // 图标+文字纵排
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(T.textSub)  // 大图标
            Text(text).font(.system(size: 14)).foregroundColor(T.textSub)               // 文案
        }
        .frame(maxWidth: .infinity)   // 撑满宽
        .padding(.vertical, 44)       // 上下留白
    }
}

/// 错误红字行：非空才显示
struct ErrorText: View {
    let text: String              // 错误文案
    var body: some View {
        if !text.isEmpty {        // 空串不占位
            Text(text).font(.system(size: 13)).foregroundColor(T.danger)  // 红字
                .frame(maxWidth: .infinity, alignment: .leading)          // 左对齐
        }
    }
}

/// 配额行（今日已用/上限）：查询输入卡顶部一行（作品/权重两页共用）
/// 右侧：VIP 用户显金色到期日（对齐安卓 QuotaRow），非 VIP 显对应类剩余次数（替代原余额显示）
struct QuotaRow: View {
    var isWeight: Bool = false    // false=作品类配额（作品分析页），true=权重类配额（权重分析页）
    @ObservedObject private var bus = SessionBus.shared               // 观察总线：配额任何变化即时刷新本行
    var body: some View {
        let used = isWeight ? bus.weightUsedToday : bus.usedToday         // 对应类今日已用
        let remain = isWeight ? bus.weightRemainingToday : bus.todayRemaining  // 对应类今日剩余
        HStack {                                                          // 左：额度，右：到期/剩余
            Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundColor(T.warn)  // 闪电图标
            Text("今日已用 \(used)/\(bus.dailyLimit <= 0 ? "∞" : String(bus.dailyLimit))")  // 已用/上限（0 视为无限）
                .font(.system(size: 12)).foregroundColor(T.textSub)
            Spacer()                                                      // 两端分布
            if bus.vipLevel != "免费用户" {   // VIP：金色到期日（只取日期段）
                Text("到期 \(String(bus.vipExpire.prefix(10)))")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(T.warn)
            } else {                              // 非 VIP：剩余查询次数
                Text("剩 \(remain) 次")
                    .font(.system(size: 12)).foregroundColor(T.primary)   // 品牌青
            }
        }
    }
}

/// 全屏 loading 遮罩：半透明黑底 + 卡片内转圈与文案
struct FullLoading: View {
    let text: String              // 提示文案
    var body: some View {
        ZStack {                  // 遮罩+卡片
            Color.black.opacity(0.55).ignoresSafeArea()  // 全屏遮罩
            VStack(spacing: 14) {                        // 卡片内容
                ProgressView().scaleEffect(1.4).tint(T.primary)  // 大号青转圈
                Text(text).font(.system(size: 14)).foregroundColor(T.textMain)  // 文案
            }
            .padding(28)                                                       // 内边距
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))       // 卡片底
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.stroke, lineWidth: 1))  // 描边
        }
    }
}

/// 通用 Toast 宿主（挂在根视图）：顶部胶囊，3.2s 自动消失，点击可关闭
struct ToastHost: View {
    @ObservedObject var bus = SessionBus.shared  // 观察总线
    var body: some View {
        VStack {                                 // 顶部悬浮容器
            if let msg = bus.toast {             // 有消息才渲染
                Text(msg)                        // 消息文本
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)                 // 内边距
                    .background(Capsule().fill(Color.black.opacity(0.82)))           // 黑胶囊底
                    .overlay(Capsule().stroke(T.stroke, lineWidth: 1))               // 描边
                    .padding(.top, 6)                                                // 顶部悬空
                    .transition(.move(edge: .top).combined(with: .opacity))          // 顶部滑入
                    .onTapGesture { bus.toast = nil }   // 点击立即关闭
                    .task {                              // 自动消失计时
                        try? await Task.sleep(nanoseconds: 3_200_000_000)  // 3.2s
                        withAnimation { bus.toast = nil }                  // 动画关闭
                    }
            }
            Spacer()                             // 靠顶
        }
        .animation(.easeInOut(duration: 0.2), value: bus.toast)  // 显隐动画
        .allowsHitTesting(bus.toast != nil)      // 无消息时不拦截触摸
    }
}

/// 自定义返回导航条（统一顶栏）
struct NavBar: View {
    let title: String            // 页面标题
    var back: () -> Void         // 返回回调
    var body: some View {
        HStack(spacing: 4) {     // 返回键+标题
            Button(action: back) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))  // 左箭头
                    .foregroundColor(T.textMain).frame(width: 40, height: 40)  // 40 见方热区
            }
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(T.textMain)  // 标题
            Spacer()             // 靠左
        }
        .padding(.horizontal, 8)
    }
}

/// 信息行（标签: 值，带提示）
struct InfoRow: View {
    let label: String                    // 左侧标签
    let value: String                    // 右侧值
    var valueColor: Color = T.textMain   // 值颜色（可定制）
    var body: some View {
        HStack(alignment: .top) {        // 顶对齐（多行值）
            Text(label).font(.system(size: 13)).foregroundColor(T.textSub)  // 灰标签
            Spacer()                     // 两端分布
            Text(value.isEmpty ? "-" : value)                                   // 空值显示 "-"
                .font(.system(size: 13)).foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)  // 多行右对齐
        }
        .padding(.vertical, 3)           // 行间距
    }
}

/// 数字指标块（竖排：值+标签）
struct MetricCell: View {
    let value: String                    // 数值（已格式化）
    let label: String                    // 标签
    var color: Color = T.textMain        // 值颜色
    var body: some View {
        VStack(spacing: 4) {             // 值上标签下
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(color)  // 大粗数值
            Text(label).font(.system(size: 11)).foregroundColor(T.textSub)             // 小灰标签
        }
        .frame(maxWidth: .infinity)      // 等分容器宽
    }
}

/// 时间戳格式化（秒/毫秒自动识别 + 字符串日期兼容）
enum Fmt {
    /// 宽松解析时间：数字时间戳（>1e12 判毫秒转秒）/ ISO 串 / 日期串
    static func time(_ raw: String?) -> Date? {
        guard var s = raw, !s.isEmpty else { return nil }       // 空输入：nil
        if let d = Double(s) {                                  // 纯数字：时间戳
            let ts = d > 1e12 ? d / 1000 : d   // 毫秒→秒（13 位以上判毫秒）
            return Date(timeIntervalSince1970: ts)
        }
        s = s.replacingOccurrences(of: "T", with: " ")          // ISO 的 T 换空格
        let f = DateFormatter()                                 // 格式器
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"                    // 完整格式
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")      // 固定东八区
        if let d = f.date(from: s) { return d }                 // 完整格式命中
        f.dateFormat = "yyyy-MM-dd"                             // 退回纯日期格式
        return f.date(from: String(s.prefix(10)))               // 截前 10 位再试
    }

    /// 月日时分（折线图轴标签）
    static func mdhm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    /// 完整时间（历史列表展示）
    static func full(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    /// 剩余天数（监控任务）：向上取整，最小 0
    static func daysLeft(_ end: String) -> Int {
        guard let d = time(end) else { return 0 }                        // 解析失败：0
        return max(0, Int(ceil(d.timeIntervalSinceNow / 86400)))         // 秒差/86400 向上取整
    }
}
