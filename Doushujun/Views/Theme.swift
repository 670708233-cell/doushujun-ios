import SwiftUI
import UIKit

// ============================================================================
// Theme.swift —— 全局「赛博科技」设计系统
// 统一管理：色板 / 渐变 / 深空背景 / 玻璃卡片 / 发光按钮 / 输入框 / 小部件
// 所有页面都从这里取样式，保证全 App 视觉一致
// ============================================================================

// MARK: - 全局色板与渐变

enum Theme {

    // ---- 深空底色（近黑的深蓝，营造夜空科技氛围）----
    static let bg = Color(red: 0.024, green: 0.043, blue: 0.086)      // 主背景 #060B16
    static let bgSoft = Color(red: 0.05, green: 0.08, blue: 0.15)     // 次级背景（弹窗/栏）

    // ---- 卡片（玻璃拟态：半透明白 + 细白描边）----
    static let cardFill = Color.white.opacity(0.055)                  // 卡片填充
    static let cardStroke = Color.white.opacity(0.10)                 // 卡片描边

    // ---- 霓虹主色（青 → 蓝 → 紫，全 App 的科技渐变三原色）----
    static let cyan = Color(red: 0.13, green: 0.83, blue: 0.93)       // 电光青
    static let blue = Color(red: 0.26, green: 0.55, blue: 1.0)        // 电光蓝
    static let purple = Color(red: 0.58, green: 0.40, blue: 1.0)      // 星云紫

    // ---- 功能色（带霓虹感）----
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.28)       // 金橙（VIP/警告）
    static let green = Color(red: 0.22, green: 0.86, blue: 0.55)      // 荧光绿（成功）
    static let red = Color(red: 1.0, green: 0.38, blue: 0.45)         // 霓虹红（错误）

    // ---- 文字层级 ----
    static let textMain = Color.white                                 // 主文字
    static let textSub = Color(red: 0.60, green: 0.68, blue: 0.84)    // 副文字（说明）
    static let textDim = Color(red: 0.45, green: 0.53, blue: 0.68)    // 弱文字（占位/时间）

    // ---- 常用渐变 ----
    /// 主渐变：蓝→紫（按钮/Logo/强调块）
    static let hero = LinearGradient(colors: [blue, purple],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    /// 赛博渐变：青→蓝→紫（横向流光，用于标题文字/描边）
    static let cyber = LinearGradient(colors: [cyan, blue, purple],
                                      startPoint: .leading, endPoint: .trailing)
    /// 金色渐变：VIP / 价格专用
    static let gold = LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.55),
                                              amber,
                                              Color(red: 0.98, green: 0.55, blue: 0.25)],
                                     startPoint: .leading, endPoint: .trailing)
    /// 成功绿渐变
    static let mint = LinearGradient(colors: [green, Color(red: 0.13, green: 0.70, blue: 0.45)],
                                     startPoint: .leading, endPoint: .trailing)
}

// MARK: - 深空背景（全 App 统一底图）

struct CyberBackground: View {

    var body: some View {
        ZStack {
            // 第一层：纯深空底色铺满全屏（忽略安全区，连刘海/底部都覆盖）
            Theme.bg.ignoresSafeArea()

            // 第二层：三个模糊霓虹光斑（模拟星云），用 GeometryReader 定位到对角
            GeometryReader { geo in
                // 左上：蓝色光斑
                Circle()
                    .fill(Theme.blue.opacity(0.16))                 // 低透明度避免抢内容
                    .frame(width: 340, height: 340)                 // 大尺寸配合大模糊半径
                    .blur(radius: 100)                              // 高斯模糊成光晕
                    .offset(x: -120, y: -100)                       // 推出左上角，只露边缘
                // 右中：紫色光斑
                Circle()
                    .fill(Theme.purple.opacity(0.15))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: geo.size.width - 180, y: geo.size.height * 0.35)
                // 左下：青色光斑（弱一些）
                Circle()
                    .fill(Theme.cyan.opacity(0.09))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: 30, y: geo.size.height - 240)
            }
            .ignoresSafeArea()

            // 第三层：细网格线（科技感电路板底纹，透明度极低不干扰阅读）
            Canvas { context, size in                              // Canvas 自绘矢量图形
                let step: CGFloat = 34                              // 网格间距 34pt
                var path = Path()                                   // 网格路径
                var x: CGFloat = 0                                  // 竖线游标
                while x <= size.width {                             // 画满横向
                    path.move(to: CGPoint(x: x, y: 0))              // 竖线起点（顶部）
                    path.addLine(to: CGPoint(x: x, y: size.height)) // 竖线终点（底部）
                    x += step                                       // 右移一格
                }
                var y: CGFloat = 0                                  // 横线游标
                while y <= size.height {                            // 画满纵向
                    path.move(to: CGPoint(x: 0, y: y))              // 横线起点（左侧）
                    path.addLine(to: CGPoint(x: size.width, y: y))  // 横线终点（右侧）
                    y += step                                       // 下移一格
                }
                // 用极低透明度白描线，形成若隐若现的网格
                context.stroke(path, with: .color(.white.opacity(0.028)), lineWidth: 0.5)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - 玻璃卡片修饰器

private struct GlassCard: ViewModifier {
    var radius: CGFloat = 20          // 圆角半径（默认 20）
    var padding: CGFloat = 18         // 内容内边距（默认 18）

    func body(content: Content) -> some View {
        content
            .padding(padding)                                          // 内边距
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.cardFill)                              // 半透明白填充
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous)) // 材质毛玻璃
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)            // 细白描边（玻璃边缘）
            )
    }
}

extension View {
    /// 任意内容一键变玻璃卡片：`.glassCard()`
    func glassCard(radius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        modifier(GlassCard(radius: radius, padding: padding))
    }
}

// MARK: - 发光渐变按钮样式

struct GlowButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.hero   // 按钮渐变（默认蓝紫）
    var height: CGFloat = 52                    // 按钮高度（默认 52）

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))  // 圆润粗体字
            .foregroundColor(.white)                                    // 白字
            .frame(maxWidth: .infinity)                                 // 横向撑满
            .frame(height: height)                                      // 固定高度
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)                                     // 渐变填充
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)         // 顶部高光描边
            )
            // 霓虹外发光：按下时收拢+缩小，松开回弹
            .shadow(color: Theme.blue.opacity(configuration.isPressed ? 0.25 : 0.5),
                    radius: configuration.isPressed ? 6 : 16, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)            // 按压缩放
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed) // 弹簧动画
    }
}

// MARK: - 统一输入框（聚焦时渐变描边+发光）

struct CyberField: View {
    var icon: String                    // 左侧 SF Symbol 图标名
    var placeholder: String             // 占位文案
    @Binding var text: String           // 双向绑定文本
    var secure = false                  // 是否密码框
    var keyboard: UIKeyboardType = .default // 键盘类型

    @FocusState private var focused: Bool   // 监听焦点状态（驱动描边发光）

    var body: some View {
        HStack(spacing: 10) {
            // 左图标：聚焦时点亮为青色，平时灰
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(focused ? Theme.cyan : Theme.textDim)
                .frame(width: 22)

            // 输入主体：密码框 / 普通框二选一
            Group {
                if secure {
                    SecureField(placeholder, text: $text)       // 密文输入
                } else {
                    TextField(placeholder, text: $text)         // 明文输入
                }
            }
            .focused($focused)                                   // 绑定焦点
            .keyboardType(keyboard)                              // 键盘类型
            .autocapitalization(.none)                           // 关闭自动大写（账号/邮箱场景）
            .disableAutocorrection(true)                         // 关闭自动纠错
            .font(.system(size: 15))
            .foregroundColor(Theme.textMain)                     // 白字
        }
        .padding(.horizontal, 14)                                // 水平内边距
        .frame(height: 50)                                       // 统一高度
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))                 // 半透明底
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused ? Theme.blue.opacity(0.8) : Theme.cardStroke, lineWidth: 1) // 聚焦渐变描边
        )
        // 聚焦时蓝紫发光
        .shadow(color: focused ? Theme.blue.opacity(0.35) : .clear, radius: 10, y: 0)
        .animation(.easeInOut(duration: 0.2), value: focused)    // 焦点切换平滑过渡
    }
}

// MARK: - 小部件

/// 板块标题行：渐变小方块图标 + 标题 + 右侧可选文字
struct SectionHeader: View {
    var icon: String          // SF Symbol 图标
    var title: String         // 标题文字
    var trailing: String = "" // 右侧附加文字（如余额），空则不显示

    var body: some View {
        HStack(spacing: 8) {
            // 渐变小圆角方块内嵌图标（板块视觉锚点）
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.hero)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
            // 标题文字（半粗体）
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textMain)
            Spacer()                                    // 把右侧文字推到行尾
            // 右侧附加文字（可空）
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textSub)
            }
        }
    }
}

/// 渐变文字修饰器：让 Text 显示为流光渐变字
struct GradientText: ViewModifier {
    var gradient: LinearGradient = Theme.cyber   // 默认赛博渐变

    func body(content: Content) -> some View {
        content
            .foregroundColor(.clear)            // 先清空原色
            .overlay(content.foregroundStyle(gradient))  // 叠一层渐变版本
    }
}

extension View {
    /// `.gradientText()` → 渐变流光文字
    func gradientText(_ gradient: LinearGradient = Theme.cyber) -> some View {
        modifier(GradientText(gradient: gradient))
    }
}

/// 六边形科技 Logo（登录页/品牌区使用）
struct HexLogo: View {
    var size: CGFloat = 88          // 外框尺寸
    var body: some View {
        ZStack {
            // 底层光晕：大一号的模糊渐变六边形
            RegularHex()
                .fill(Theme.hero)
                .frame(width: size + 26, height: size + 26)
                .blur(radius: 22)
                .opacity(0.55)
            // 中层：渐变六边形本体
            RegularHex()
                .fill(Theme.hero)
                .frame(width: size, height: size)
                .overlay(
                    RegularHex()
                        .stroke(.white.opacity(0.35), lineWidth: 1.5)   // 高光描边
                )
            // 顶层：闪电图标（数据/能量的符号）
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

/// 正六边形 Shape（RegularHex 供 HexLogo 使用）
struct RegularHex: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()                                  // 路径
        let c = CGPoint(x: rect.midX, y: rect.midY)     // 中心点
        let r = min(rect.width, rect.height) / 2        // 半径
        // 六个顶点：从 -90° 开始每 60° 一个
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2                  // 角度
            let pt = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle)) // 顶点坐标
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }     // 首点 move 其余 line
        }
        p.closeSubpath()                                // 闭合
        return p
    }
}
