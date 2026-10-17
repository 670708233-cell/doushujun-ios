import SwiftUI

/// 原生滑块验证组件（web 端 slider captcha 同款流程）：
/// generate 拿 aes_key/iv -> 手势采集轨迹 -> AES-CBC 加密 -> verify 拿 slider_token
struct SliderCaptchaView: View {
    /// 验证成功后回写 slider_token
    var onVerified: (String) -> Void

    @State private var seed: API.SliderSeed?
    @State private var dragging = false
    @State private var offset: CGFloat = 0
    @State private var trajectory: [[String: Any]] = []
    @State private var dragStart = Date()
    @State private var statusText = "按住滑块，拖动到最右侧完成验证"
    @State private var verifying = false
    @State private var verified = false

    private let trackHeight: CGFloat = 48
    private let knobSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.11, green: 0.16, blue: 0.28))
                if verified {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.3, green: 0.75, blue: 0.42))
                        Text("验证成功")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.3, green: 0.75, blue: 0.42))
                    }
                } else {
                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                }
                // 轨道 + 滑块
                HStack {
                    if !verified {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.25))
                            .frame(width: max(0, offset + knobSize))
                            .frame(maxHeight: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
                HStack {
                    knob
                    Spacer()
                }
            }
            .frame(height: trackHeight)
        }
        .task { await refresh() }
    }

    private var knob: some View {
        Image(systemName: verified ? "lock.fill" : "chevron.right.2")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: knobSize, height: knobSize)
            .background(verified
                        ? AnyShapeStyle(Color(red: 0.3, green: 0.75, blue: 0.42))
                        : AnyShapeStyle(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                       startPoint: .top, endPoint: .bottom)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .offset(x: verified ? 0 : offset)
            .gesture(verified ? nil : dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    dragStart = Date()
                    trajectory = []
                    recordPoint(x: 0, y: value.translation.height)
                }
                let maxMove = max(1, UIScreen.main.bounds.width - 80 - knobSize)
                offset = min(maxMove, max(0, value.translation.width))
                recordPoint(x: value.translation.width, y: value.translation.height)
            }
            .onEnded { _ in
                dragging = false
                let maxMove = max(1, UIScreen.main.bounds.width - 80 - knobSize)
                let ratio = Double(offset / maxMove)
                if ratio >= 0.85 {
                    Task { await submit(ratio: ratio) }
                } else {
                    withAnimation(.spring()) { offset = 0 }
                    statusText = "请拖动到最右侧"
                }
            }
    }

    private func recordPoint(x: CGFloat, y: CGFloat) {
        let t = Int(Date().timeIntervalSince(dragStart) * 1000)
        trajectory.append(["x": Double(x), "y": Double(y), "t": t])
    }

    /// 刷新滑块种子
    func refresh() async {
        verified = false
        verifying = false
        withAnimation { offset = 0 }
        trajectory = []
        statusText = "按住滑块，拖动到最右侧完成验证"
        do {
            seed = try await API.generateSliderSeed()
        } catch {
            statusText = "滑块加载失败：\(error.localizedDescription)"
        }
    }

    private func submit(ratio: Double) async {
        guard let s = seed, !verifying else { return }
        verifying = true
        statusText = "正在验证..."
        defer {
            verifying = false
            if !verified {
                withAnimation { offset = 0 }
            }
        }

        let totalTime = Int(Date().timeIntervalSince(dragStart) * 1000)
        let track: [String: Any] = [
            "ratio": min(1.0, max(0.0, ratio)),
            "total_time": max(totalTime, 600),
            "trajectory": trajectory,
            "pause_count": 0,
            "point_count": trajectory.count,
            "mouse_down_count": 1,
            "screen_width": Double(UIScreen.main.bounds.width),
            "screen_height": Double(UIScreen.main.bounds.height),
            "noise": [Any](),
        ]
        do {
            let token = try await API.verifySlider(captchaKey: s.captchaKey,
                                                   aesKey: s.aesKey,
                                                   aesIv: s.aesIv,
                                                   track: track)
            verified = true
            statusText = ""
            onVerified(token)
        } catch {
            statusText = "验证未通过，已刷新，请重试"
            await refresh()
        }
    }
}
