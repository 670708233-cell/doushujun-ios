import SwiftUI

// ============================================================================
// SliderCaptchaView —— 原生滑块验证组件（web 端 slider captcha 同款流程）
// 流程：generate 拿 aes_key/iv → 手势采集轨迹 → AES-CBC 加密上报 → verify 拿 token
// 对外签名不变：onVerified(token) 回调 slider_token
// ============================================================================

struct SliderCaptchaView: View {

    // MARK: - 对外接口

    /// 验证成功后回写 slider_token（登录/注册页接收后随表单提交）
    var onVerified: (String) -> Void

    // MARK: - 内部状态

    @State private var seed: API.SliderSeed?            // 服务端下发的滑块种子（key/aes）
    @State private var dragging = false                 // 是否正在拖动
    @State private var offset: CGFloat = 0              // 滑块当前水平位移
    @State private var trajectory: [[String: Any]] = [] // 采集的轨迹点 [{x,y,t}]
    @State private var dragStart = Date()               // 本次拖动起始时间（算 total_time）
    @State private var statusText = "按住滑块，拖动到最右侧完成验证" // 底部提示文案
    @State private var verifying = false                // 正在提交验证（防重复提交）
    @State private var verified = false                 // 是否已验证成功

    // MARK: - 尺寸常量

    private let trackHeight: CGFloat = 52               // 轨道高度
    private let knobSize: CGFloat = 44                  // 滑块尺寸

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 6) {
            // ---- 轨道区 ----
            ZStack {
                // 底：玻璃轨道（半透明 + 内描边）
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)

                // 已验证态：整条轨道变荧光绿渐变 + 打勾文案
                if verified {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.mint.opacity(0.22))
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")       // 盾形对勾图标
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.green)
                        Text("验证成功")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.green)
                    }
                } else {
                    // 未验证态：提示文案（验证中显示转圈）
                    HStack(spacing: 8) {
                        if verifying {
                            ProgressView().tint(Theme.cyan)            // 小菊花
                        }
                        Text(statusText)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSub)
                    }
                }

                // 已滑过区域：青→紫渐变填充（随 offset 增长），带淡光
                HStack {
                    if !verified {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.cyan.opacity(0.30),
                                                          Theme.blue.opacity(0.22)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, offset + knobSize))    // 宽度=位移+滑块宽
                            .frame(maxHeight: .infinity, alignment: .leading) // 左对齐
                    }
                    Spacer()
                }

                // 滑块本体（浮在最上层）
                HStack {
                    if !verified {
                        knob
                        Spacer()
                    }
                }
            }
            .frame(height: trackHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: verified) // 状态切换弹性过渡
        }
        .task { await refresh() }   // 首次出现时加载滑块种子
    }

    // MARK: - 滑块按钮

    private var knob: some View {
        Image(systemName: verified ? "lock.fill" : "chevron.right.2")  // 成功后变锁图标
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: knobSize, height: knobSize)
            .background(
                // 渐变填充：验证中青→紫，成功变绿
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(verified ? AnyShapeStyle(Theme.mint) : AnyShapeStyle(Theme.hero))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.4), lineWidth: 1)          // 白描边提亮
            )
            // 拖动时蓝紫霓虹发光
            .shadow(color: Theme.blue.opacity(dragging ? 0.7 : 0.35), radius: dragging ? 12 : 6)
            .offset(x: verified ? 0 : offset)                            // 位移驱动
            .gesture(verified ? nil : dragGesture)                       // 成功后禁用手势
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: dragging)
    }

    // MARK: - 拖动手势

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // 首次回调：开始一次新拖动，重置计时与轨迹
                if !dragging {
                    dragging = true
                    dragStart = Date()
                    trajectory = []
                    recordPoint(x: 0, y: value.translation.height)       // 记录起点
                }
                // 最大可滑动距离 = 屏宽 - 左右留白 - 滑块宽
                let maxMove = max(1, UIScreen.main.bounds.width - 80 - knobSize)
                offset = min(maxMove, max(0, value.translation.width))   // 限幅
                recordPoint(x: value.translation.width, y: value.translation.height) // 逐点采集
            }
            .onEnded { _ in
                dragging = false
                let maxMove = max(1, UIScreen.main.bounds.width - 80 - knobSize)
                let ratio = Double(offset / maxMove)                     // 滑动完成度 0~1
                if ratio >= 0.85 {
                    // 拖过 85% 视为意图完成，提交验证（服务端校验 ratio 落在目标位）
                    Task { await submit(ratio: ratio) }
                } else {
                    // 拖太短：弹回原位并提示
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = 0 }
                    statusText = "请拖动到最右侧"
                }
            }
    }

    /// 记录一个轨迹点（x/y 相对位移 + 相对起点毫秒时间）
    private func recordPoint(x: CGFloat, y: CGFloat) {
        let t = Int(Date().timeIntervalSince(dragStart) * 1000)
        trajectory.append(["x": Double(x), "y": Double(y), "t": t])
    }

    // MARK: - 刷新种子

    /// 重新向服务端申请滑块种子（验证失败/手动刷新时调用）
    @MainActor
    func refresh() async {
        verified = false
        verifying = false
        withAnimation { offset = 0 }
        trajectory = []
        statusText = "按住滑块，拖动到最右侧完成验证"
        do {
            seed = try await API.generateSliderSeed()   // GET /captcha/slider/generate
        } catch {
            statusText = "滑块加载失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 提交验证

    @MainActor
    private func submit(ratio: Double) async {
        guard let s = seed, !verifying else { return }  // 无种子或正在验证则忽略
        verifying = true
        statusText = "正在验证..."

        let totalTime = Int(Date().timeIntervalSince(dragStart) * 1000) // 拖动总时长(ms)
        let points = trajectory                                          // 轨迹快照
        // 组装轨迹数据（字段与 web 端完全一致，服务端按这些字段做反作弊校验）
        let track: [String: Any] = [
            "ratio": min(1.0, max(0.0, ratio)),              // 完成度（目标位校验）
            "total_time": max(totalTime, 600),               // 至少 600ms（过快=机器人）
            "trajectory": points,                            // 轨迹点数组
            "pause_count": 0,                                // 停顿次数
            "point_count": points.count,                     // 采样点数
            "mouse_down_count": 1,                           // 按下次数
            "screen_width": Double(UIScreen.main.bounds.width),
            "screen_height": Double(UIScreen.main.bounds.height),
            "noise": [Any](),                                // 噪声数组（保留字段）
        ]
        do {
            // AES-CBC 加密轨迹 → POST /captcha/slider/verify → slider_token
            let token = try await API.verifySlider(captchaKey: s.captchaKey,
                                                   aesKey: s.aesKey,
                                                   aesIv: s.aesIv,
                                                   track: track)
            verified = true                                   // 切换成功态
            statusText = ""
            onVerified(token)                                 // 回调 token 给上层
        } catch {
            statusText = "验证未通过，已刷新，请重试"
        }
        verifying = false
        if !verified {
            // 失败：弹回 + 自动换新种子重新来
            withAnimation { offset = 0 }
            await refresh()
        }
    }
}
