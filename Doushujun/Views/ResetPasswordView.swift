import SwiftUI

// ============================================================================
// ResetPasswordView —— 找回密码（web 端同款）
// 流程：输入注册邮箱 → 校验邮箱已注册 → 发送重置验证码（60s 冷却）→ 提交新密码
// ============================================================================

struct ResetPasswordView: View {

    @Environment(\.dismiss) private var dismiss       // 关闭弹窗

    // MARK: - 状态

    @State private var email = ""                     // 注册邮箱
    @State private var emailCode = ""                 // 邮箱验证码
    @State private var newPassword = ""               // 新密码

    @State private var sendingCode = false            // 发送验证码中
    @State private var countdown = 0                  // 重发倒计时
    @State private var timer: Timer?                  // 倒计时定时器
    @State private var isLoading = false              // 提交中
    @State private var errorMessage = ""              // 错误提示
    @State private var successMessage = ""            // 成功提示

    var body: some View {
        ZStack {
            CyberBackground()                                  // 统一深空背景

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 顶部标题栏 ----
                    HStack {
                        Button { dismiss() } label: {           // 关闭
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textMain)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                                .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                        }
                        Spacer()
                        Text("找回密码")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .gradientText(Theme.cyber)
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // ---- 表单玻璃卡 ----
                    VStack(spacing: 14) {

                        SectionHeader(icon: "key.radiowaves.forward.fill", title: "通过邮箱重置")

                        // 说明文字
                        Text("输入注册邮箱，接收验证码后设置新密码")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.textSub)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 注册邮箱
                        CyberField(icon: "envelope.fill",
                                   placeholder: "注册邮箱",
                                   text: $email,
                                   keyboard: .emailAddress)

                        // 邮箱验证码行：输入 + 发送按钮（先 checkEmailForReset 再发码）
                        HStack(spacing: 10) {
                            CyberField(icon: "envelope.open.fill",
                                       placeholder: "邮箱验证码",
                                       text: $emailCode,
                                       keyboard: .numberPad)
                            Button {
                                Task { await sendCode() }
                            } label: {
                                Text(sendingCode ? "发送中" : (countdown > 0 ? "\(countdown)s" : "获取验证码"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(countdown > 0 ? Theme.textDim : .white)
                                    .frame(width: 96, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(countdown > 0 ? AnyShapeStyle(Color.white.opacity(0.05)) : AnyShapeStyle(Theme.hero))
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.25), lineWidth: 1))
                            }
                            .disabled(sendingCode || countdown > 0)
                        }

                        // 新密码
                        CyberField(icon: "lock.rotation",
                                   placeholder: "新密码（不少于6位）",
                                   text: $newPassword,
                                   secure: true)

                        // 错误 / 成功提示
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13)).foregroundStyle(Theme.red)
                                Text(errorMessage).font(.system(size: 13)).foregroundColor(Theme.red)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.10)))
                        }
                        if !successMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13)).foregroundStyle(Theme.green)
                                Text(successMessage).font(.system(size: 13)).foregroundColor(Theme.green)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.green.opacity(0.10)))
                        }

                        // 重置密码主按钮
                        Button {
                            Task { await doReset() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("重置密码")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.hero))
                        .disabled(isLoading)
                    }
                    .glassCard(radius: 22, padding: 18)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }
            }
        }
        .onDisappear { timer?.invalidate() }              // 退出清定时器
    }

    // MARK: - 网络动作

    /// 发送重置验证码：先校验邮箱已注册 → 发码 → 倒计时
    private func sendCode() async {
        errorMessage = ""
        successMessage = ""
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "请输入正确的邮箱地址"; return
        }
        sendingCode = true
        defer { sendingCode = false }
        do {
            try await API.checkEmailForReset(email)        // POST /reset_password/checkEmailForReset
            try await API.sendResetCode(email)             // POST /reset_password/sendResetCode
            successMessage = "验证码已发送，请查收邮箱"
            startCountdown()                               // 60s 冷却
        } catch {
            errorMessage = error.localizedDescription       // 邮箱未注册等后端错误
        }
    }

    /// 60 秒重发倒计时
    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                countdown -= 1
                if countdown <= 0 { t.invalidate() }
            }
        }
    }

    /// 提交重置密码
    private func doReset() async {
        errorMessage = ""
        successMessage = ""
        guard !email.isEmpty, !emailCode.isEmpty else {
            errorMessage = "请填写邮箱和验证码"; return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "新密码不少于 6 位"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await API.resetPassword(email: email,        // POST /reset_password/resetPassword
                                        emailCode: emailCode,
                                        newPassword: newPassword)
            successMessage = "密码重置成功，请返回使用新密码登录"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()                                     // 回登录页
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
