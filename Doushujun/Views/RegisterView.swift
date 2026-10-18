import SwiftUI

// ============================================================================
// RegisterView —— 注册新账号（web 端同款流程）
// 字段：用户名(查重)/邮箱/密码/图形验证码 → 发邮箱验证码 → 提交注册
// 附：注册配置（是否开放注册/新用户奖励/允许的邮箱域名）
// ============================================================================

struct RegisterView: View {

    // MARK: - 状态

    @Environment(\.dismiss) private var dismiss       // 关闭弹窗

    @State private var regInfo: RegisterInfo?         // 服务端注册配置
    @State private var username = ""                  // 用户名
    @State private var email = ""                     // 邮箱
    @State private var password = ""                  // 密码
    @State private var confirmPassword = ""           // 确认密码
    @State private var inviteCode = ""                // 邀请码（可选）
    @State private var captchaCode = ""               // 图形验证码输入
    @State private var captcha: API.CaptchaImage?     // 图形验证码数据
    @State private var emailCode = ""                 // 邮箱验证码
    @State private var checkingUsername = false       // 用户名查重中
    @State private var usernameAvailable: Bool?       // 查重结果（nil=未查）
    @State private var sendingCode = false            // 发送邮箱验证码中
    @State private var countdown = 0                  // 重发倒计时
    @State private var timer: Timer?                  // 倒计时定时器
    @State private var isLoading = false              // 注册请求中
    @State private var errorMessage = ""              // 错误提示
    @State private var successMessage = ""            // 成功提示
    @State private var checkTask: Task<Void, Never>?  // 用户名查重防抖任务

    var body: some View {
        ZStack {
            CyberBackground()                                 // 统一深空背景

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 顶部标题栏：关闭按钮 + 标题 ----
                    HStack {
                        Button { dismiss() } label: {          // 关闭
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textMain)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                                .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                        }
                        Spacer()
                        Text("注册新账号")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .gradientText(Theme.cyber)
                        Spacer()
                        Color.clear.frame(width: 36, height: 36) // 占位保持标题居中
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // ---- 表单玻璃卡 ----
                    VStack(spacing: 14) {

                        // 新用户奖励提示条（服务端配置了奖励才显示）
                        if let bonus = regInfo?.newUserBonus, bonus > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.amber)
                                Text("新用户注册即送 ¥\(String(format: "%.2f", bonus)) 查询余额")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(Theme.amber)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.10)))
                        }

                        // 用户名（右侧实时查重状态）
                        HStack(spacing: 10) {
                            CyberField(icon: "at",
                                       placeholder: "用户名",
                                       text: $username)
                                .frame(maxWidth: .infinity)
                                .onChange(of: username) { _ in      // 输入变化 → 防抖查重
                                    usernameAvailable = nil
                                    debounceCheck()
                                }
                            // 查重状态图标
                            if checkingUsername {
                                ProgressView().tint(Theme.cyan).scaleEffect(0.8)
                            } else if let ok = usernameAvailable {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(ok ? Theme.green : Theme.red)
                            }
                        }

                        // 邮箱
                        CyberField(icon: "envelope.fill",
                                   placeholder: "邮箱",
                                   text: $email,
                                   keyboard: .emailAddress)

                        // 允许的邮箱域名提示
                        if let domains = regInfo?.allowedEmailDomains, !domains.isEmpty {
                            Text("支持邮箱：\(domains.joined(separator: " / "))")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textDim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 密码 / 确认密码
                        CyberField(icon: "lock.fill", placeholder: "密码（不少于6位）", text: $password, secure: true)
                        CyberField(icon: "lock.shield.fill", placeholder: "确认密码", text: $confirmPassword, secure: true)

                        // 图形验证码行（发送邮箱验证码的前置校验）
                        HStack(spacing: 10) {
                            CyberField(icon: "shield.lefthalf.filled",
                                       placeholder: "图形验证码",
                                       text: $captchaCode)
                                .frame(maxWidth: .infinity)
                            captchaImage                             // 验证码图
                                .frame(width: 112, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.cardStroke, lineWidth: 1))
                                .onTapGesture { Task { await loadCaptcha() } }
                        }

                        // 邮箱验证码行：输入 + 发送按钮（60s 倒计时）
                        HStack(spacing: 10) {
                            CyberField(icon: "envelope.open.fill",
                                       placeholder: "邮箱验证码",
                                       text: $emailCode,
                                       keyboard: .numberPad)
                            Button {
                                Task { await sendCode() }            // 发送验证码
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
                            .disabled(sendingCode || countdown > 0)   // 冷却/发送中禁用
                        }

                        // 邀请码（可选）
                        CyberField(icon: "ticket.fill",
                                   placeholder: "邀请码（选填）",
                                   text: $inviteCode)

                        // 错误 / 成功提示条
                        if !errorMessage.isEmpty {
                            tipBanner(text: errorMessage, color: Theme.red, icon: "exclamationmark.triangle.fill")
                        }
                        if !successMessage.isEmpty {
                            tipBanner(text: successMessage, color: Theme.green, icon: "checkmark.circle.fill")
                        }

                        // 注册主按钮
                        Button {
                            Task { await doRegister() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("注 册")
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
        // 进入页面：拉注册配置 + 验证码；退出：清定时器
        .task {
            await loadRegInfo()
            await loadCaptcha()
        }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - 小部件

    /// 提示条（错误红/成功绿）
    private func tipBanner(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
            Text(text).font(.system(size: 13)).foregroundColor(color)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.10)))
    }

    @ViewBuilder
    private var captchaImage: some View {
        if let cap = captcha,
           let data = Data(base64Encoded: cleanBase64(cap.base64Image)),
           let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFit().background(Color.white)
        } else {
            ZStack {
                Rectangle().fill(Color.white.opacity(0.06))
                Text("点击刷新").font(.system(size: 11)).foregroundColor(Theme.textDim)
            }
        }
    }

    private func cleanBase64(_ s: String) -> String {
        var t = s
        if let r = t.range(of: "base64,") { t = String(t[r.upperBound...]) }
        return t
    }

    // MARK: - 用户名查重（防抖）

    private func debounceCheck() {
        checkTask?.cancel()                            // 取消上一次未执行的查重
        let name = username
        checkTask = Task {                             // 新起延迟任务
            try? await Task.sleep(nanoseconds: 600_000_000)  // 停 600ms（防抖窗口）
            guard !Task.isCancelled else { return }    // 已取消则不再查
            guard name.count >= 3 else { return }      // 太短不查
            checkingUsername = true
            defer { checkingUsername = false }
            do {
                usernameAvailable = try await API.checkUsername(name) // POST /user/check-username
            } catch {
                usernameAvailable = nil                // 查询失败静默
            }
        }
    }

    // MARK: - 网络动作

    /// 拉取注册配置（是否开放/奖励/邮箱域名）
    private func loadRegInfo() async {
        regInfo = try? await API.fetchRegisterInfo()                  // 失败不阻塞注册
    }

    /// 拉取图形验证码
    private func loadCaptcha() async {
        errorMessage = ""
        captcha = try? await API.generateCaptcha()
        captchaCode = ""
    }

    /// 发送邮箱验证码：图形码校验 → 发送 → 60s 倒计时
    private func sendCode() async {
        errorMessage = ""
        successMessage = ""
        // 前置校验
        guard !email.isEmpty else { errorMessage = "请先输入邮箱"; return }
        guard let cap = captcha, !cap.captchaKey.isEmpty else { errorMessage = "请先获取图形验证码"; return }
        guard !captchaCode.isEmpty else { errorMessage = "请输入图形验证码"; return }
        sendingCode = true
        defer { sendingCode = false }
        do {
            // POST /user/sendcode（web 同款：邮箱+图形码）
            try await API.sendEmailCode(userEmail: email,
                                        captchaKey: cap.captchaKey,
                                        captchaCode: captchaCode)
            successMessage = "验证码已发送，请查收邮箱"
            startCountdown()                                          // 启动 60s 冷却
        } catch {
            errorMessage = error.localizedDescription
            await loadCaptcha()                                       // 图形码失败自动换新
        }
    }

    /// 启动 60 秒重发倒计时
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

    /// 提交注册
    private func doRegister() async {
        errorMessage = ""
        successMessage = ""
        // ---- 表单校验 ----
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "请填写完整信息"; return
        }
        guard password.count >= 6 else { errorMessage = "密码不少于 6 位"; return }
        guard password == confirmPassword else { errorMessage = "两次输入的密码不一致"; return }
        guard let cap = captcha, !cap.captchaKey.isEmpty else { errorMessage = "请先获取图形验证码"; return }
        guard !captchaCode.isEmpty else { errorMessage = "请输入图形验证码"; return }
        guard !emailCode.isEmpty else { errorMessage = "请输入邮箱验证码"; return }

        isLoading = true
        defer { isLoading = false }
        do {
            // POST /user/register（web 同款参数）
            try await API.register(username: username,
                                   email: email,
                                   password: password,
                                   emailCode: emailCode,
                                   captchaKey: cap.captchaKey,
                                   captchaCode: captchaCode)
            successMessage = "注册成功！1.5 秒后返回登录"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()                                             // 回登录页
            }
        } catch {
            errorMessage = error.localizedDescription
            await loadCaptcha()
        }
    }
}
