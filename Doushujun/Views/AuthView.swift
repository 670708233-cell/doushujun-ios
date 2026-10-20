import SwiftUI
import WebKit

/// 登录/注册/忘记密码（对齐安卓 AuthScreens.kt：mode 单页切换）
struct AuthView: View {
    var onLoginSuccess: () -> Void
    @State private var mode = "login"
    @ObservedObject private var bus = SessionBus.shared

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer().frame(height: 34)
                    // Logo 区
                    RoundedRectangle(cornerRadius: 22)
                        .fill(T.grad)
                        .frame(width: 84, height: 84)
                        .overlay(Text("抖数君").font(.system(size: 22, weight: .heavy)).foregroundColor(T.bg))
                    Text("AI作品分析建议优化平台")
                        .font(.system(size: 15)).tracking(2).foregroundColor(T.textSub)

                    switch mode {
                    case "login": LoginPanel(onSuccess: onLoginSuccess, goRegister: { mode = "register" }, goForgot: { mode = "forgot" })
                    case "register": RegisterPanel(onSuccess: onLoginSuccess, goLogin: { mode = "login" })
                    default: ForgotPanel(onDone: { mode = "login" }, goLogin: { mode = "login" })
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear { bus.loadAnnouncement() }
    }
}

// MARK: - 图形验证码（GET captcha/generate → base64 PNG dataURI）

struct CaptchaImage: View {
    @Binding var captchaKey: String
    @Binding var code: String
    @State private var img: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            DSJField(placeholder: "图形验证码", text: $code)
            Button {
                refresh()
            } label: {
                Group {
                    if let img = img {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Text("点击刷新").font(.system(size: 11)).foregroundColor(T.textSub)
                    }
                }
                .frame(width: 110, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
            }
        }
        .onAppear { refresh() }
    }

    func refresh() {
        code = ""
        Task {
            do {
                let d = try await Network.get("captcha/generate")
                let uri = d["captcha_image"].str ?? ""
                let b64 = uri.replacingOccurrences(of: "^data:image/\\w+;base64,", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                await MainActor.run {
                    img = Data(base64Encoded: b64).flatMap(UIImage.init)
                    captchaKey = d["captcha_key"].str ?? ""
                }
            } catch {
                await MainActor.run { img = nil; captchaKey = "" }
            }
        }
    }
}

// MARK: - 登录面板

private struct LoginPanel: View {
    var onSuccess: () -> Void
    var goRegister: () -> Void
    var goForgot: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var captchaCode = ""
    @State private var captchaKey = ""
    @State private var loading = false
    @State private var error = ""
    @State private var showGeeTest = false
    @State private var showWechatTip = false
    @ObservedObject private var bus = SessionBus.shared

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(text: "登录")
                    DSJField(placeholder: "用户名或邮箱", text: $username)
                    DSJField(placeholder: "密码", text: $password, secure: true)
                    CaptchaImage(captchaKey: $captchaKey, code: $captchaCode)
                    ErrorText(text: error)
                    PrimaryButton(title: "登  录", loading: loading) { showGeeTest = true }
                }
            }
            HStack {
                Button("注册新账号", action: goRegister).foregroundColor(T.primary)
                Spacer()
                Button("忘记密码？", action: goForgot).foregroundColor(T.textSub)
            }
            .font(.system(size: 13))
            Divider().overlay(Color.white.opacity(0.1))
            // 微信登录占位（对齐安卓：提示需开放平台资质）
            Button { showWechatTip = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                    Text("微信登录")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "07C160")).opacity(0.85))
            }
        }
        .sheet(isPresented: $showGeeTest) {
            SliderCaptchaSheet { sliderToken in
                showGeeTest = false
                Task { await doLogin(sliderToken: sliderToken) }
            } onClosed: {
                showGeeTest = false
            }
        }
        .alert("微信登录暂未开放", isPresented: $showWechatTip) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("需微信开放平台移动应用资质，当前请使用账号密码登录")
        }
    }

    private func doLogin(sliderToken: String) async {
        let un = username.trimmingCharacters(in: .whitespaces)
        let pw = password
        guard !un.isEmpty, !pw.isEmpty else { error = "请输入账号和密码"; return }
        if captchaKey.isEmpty && !captchaCode.isEmpty { error = "请输入图形验证码"; return }
        loading = true
        error = ""
        defer { loading = false }
        do {
            var body: [String: Any] = [
                "username": un,
                "password": pw,
                "captcha_key": captchaKey,
                "captcha_code": captchaCode.trimmingCharacters(in: .whitespaces),
            ]
            if !sliderToken.isEmpty { body["slider_token"] = sliderToken }
            let d = try await Network.post("user/login", body: body)
            let token = d["token"].str ?? ""
            guard !token.isEmpty else { throw ApiError.business("登录失败，请稍后重试") }
            SessionStore.saveLogin(token: token,
                                   username: d["username"].str,
                                   email: d["email"].str,
                                   balance: d["balance"].dbl)
            bus.syncLogin(username: d["username"].str, email: d["email"].str, balance: d["balance"].dbl)
            bus.refreshAccount()
            onSuccess()
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "登录失败，请稍后重试"
            captchaCode = ""
        }
    }
}

// MARK: - 注册面板

private struct RegisterPanel: View {
    var onSuccess: () -> Void
    var goLogin: () -> Void

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var inviteCode = ""
    @State private var captchaCode = ""
    @State private var captchaKey = ""
    @State private var emailCode = ""
    @State private var loading = false
    @State private var sending = false
    @State private var countdown = 0
    @State private var error = ""
    @State private var showGeeTest = false
    private let emailRe = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(text: "注册新账号")
                    DSJField(placeholder: "用户名（至少3个字符）", text: $username)
                    DSJField(placeholder: "邮箱", text: $email, keyboard: .emailAddress)
                    DSJField(placeholder: "密码（至少6位）", text: $password, secure: true)
                    DSJField(placeholder: "确认密码", text: $confirm, secure: true)
                    DSJField(placeholder: "邀请码（选填，好友邀请必填）", text: $inviteCode)
                    CaptchaImage(captchaKey: $captchaKey, code: $captchaCode)
                    // 邮箱验证码行
                    HStack(spacing: 10) {
                        DSJField(placeholder: "邮箱验证码", text: $emailCode, keyboard: .numberPad)
                        Button {
                            Task { await sendCode() }
                        } label: {
                            Text(sending ? "发送中" : (countdown > 0 ? "\(countdown)s" : "获取验证码"))
                                .font(.system(size: 13, weight: .medium)).foregroundColor(T.primary)
                                .frame(width: 92, height: 46)
                                .background(RoundedRectangle(cornerRadius: 12).fill(T.primary.opacity(0.12)))
                        }
                        .disabled(sending || countdown > 0)
                    }
                    ErrorText(text: error)
                    PrimaryButton(title: "注  册", loading: loading) { showGeeTest = true }
                }
            }
            Button("已有账号？返回登录", action: goLogin)
                .font(.system(size: 13)).foregroundColor(T.textSub)
        }
        .task {
            // 倒计时驱动
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
        .sheet(isPresented: $showGeeTest) {
            SliderCaptchaSheet { sliderToken in
                showGeeTest = false
                Task { await doRegister(sliderToken: sliderToken) }
            } onClosed: {
                showGeeTest = false
            }
        }
    }

    private func sendCode() async {
        let em = email.trimmingCharacters(in: .whitespaces)
        guard em.range(of: emailRe, options: .regularExpression) != nil else { error = "邮箱格式不正确"; return }
        guard !captchaCode.trimmingCharacters(in: .whitespaces).isEmpty else { error = "请输入图形验证码"; return }
        sending = true
        error = ""
        defer { sending = false }
        do {
            _ = try await Network.post("user/sendcode", body: [
                "email": em,
                "captcha_key": captchaKey,
                "captcha_code": captchaCode.trimmingCharacters(in: .whitespaces),
            ])
            countdown = 60
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "发送失败"
            captchaCode = ""
        }
    }

    private func doRegister(sliderToken: String) async {
        let un = username.trimmingCharacters(in: .whitespaces)
        let em = email.trimmingCharacters(in: .whitespaces)
        let ec = emailCode.trimmingCharacters(in: .whitespaces)
        guard un.count >= 3 else { error = "用户名至少3个字符"; return }
        guard password.count >= 6 else { error = "密码至少6位"; return }
        guard password == confirm else { error = "两次密码不一致"; return }
        guard !ec.isEmpty else { error = "请输入邮箱验证码"; return }
        loading = true
        error = ""
        defer { loading = false }
        do {
            _ = try await Network.post("user/register", body: [
                "username": un,
                "email": em,
                "password": password,
                "email_code": ec,
                "captcha_key": captchaKey,
                "captcha_code": captchaCode.trimmingCharacters(in: .whitespaces),
                "slider_token": sliderToken,
                "invite_code": inviteCode.trimmingCharacters(in: .whitespaces),
            ])
            onSuccess()
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "注册失败"
            captchaCode = ""
        }
    }
}

// MARK: - 忘记密码（两阶段三步）

private struct ForgotPanel: View {
    var onDone: () -> Void
    var goLogin: () -> Void

    @State private var email = ""
    @State private var checked = false
    @State private var emailCode = ""
    @State private var newPassword = ""
    @State private var sending = false
    @State private var countdown = 0
    @State private var loading = false
    @State private var error = ""

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(text: "找回密码")
                    if !checked {
                        DSJField(placeholder: "注册邮箱", text: $email, keyboard: .emailAddress)
                        ErrorText(text: error)
                        PrimaryButton(title: "下一步", loading: loading) {
                            Task { await checkEmail() }
                        }
                    } else {
                        Text("验证码已发送至 \(email)")
                            .font(.system(size: 13)).foregroundColor(T.textSub)
                        HStack(spacing: 10) {
                            DSJField(placeholder: "邮箱验证码", text: $emailCode, keyboard: .numberPad)
                            Button {
                                Task { await sendResetCode() }
                            } label: {
                                Text(sending ? "发送中" : (countdown > 0 ? "\(countdown)s" : "重发"))
                                    .font(.system(size: 13, weight: .medium)).foregroundColor(T.primary)
                                    .frame(width: 70, height: 46)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(T.primary.opacity(0.12)))
                            }
                            .disabled(sending || countdown > 0)
                        }
                        DSJField(placeholder: "新密码（至少6位）", text: $newPassword, secure: true)
                        ErrorText(text: error)
                        PrimaryButton(title: "重置密码", loading: loading) {
                            Task { await reset() }
                        }
                    }
                }
            }
            Button("返回登录", action: goLogin).font(.system(size: 13)).foregroundColor(T.textSub)
        }
        .task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }

    private func checkEmail() async {
        let em = email.trimmingCharacters(in: .whitespaces)
        guard !em.isEmpty else { error = "请输入邮箱"; return }
        loading = true
        error = ""
        defer { loading = false }
        do {
            _ = try await Network.post("reset_password/checkEmailForReset", body: ["email": em])
            checked = true
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "邮箱验证失败"
        }
    }

    private func sendResetCode() async {
        sending = true
        defer { sending = false }
        do {
            _ = try await Network.post("reset_password/sendResetCode", body: ["email": email.trimmingCharacters(in: .whitespaces)])
            countdown = 60
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "发送失败"
        }
    }

    private func reset() async {
        guard newPassword.count >= 6 else { error = "新密码至少6位"; return }
        guard !emailCode.trimmingCharacters(in: .whitespaces).isEmpty else { error = "请输入邮箱验证码"; return }
        loading = true
        error = ""
        defer { loading = false }
        do {
            _ = try await Network.post("reset_password/resetPassword", body: [
                "email": email.trimmingCharacters(in: .whitespaces),
                "email_code": emailCode.trimmingCharacters(in: .whitespaces),
                "new_password": newPassword,
            ])
            onDone()
        } catch {
            self.error = (error as? ApiError)?.errorDescription ?? "重置失败"
        }
    }
}

// MARK: - 自研滑块验证弹窗（对齐 web SliderCaptcha.vue：generate 发 AES 密钥 → 拖动采轨迹 → AES-CBC 加密上送 verify 换 slider_token）

struct SliderCaptchaSheet: View {
    var onVerified: (String) -> Void   // 验证通过回传 slider_token
    var onClosed: () -> Void

    // ---- 验证会话（captcha/slider/generate 返回）----
    @State private var captchaKey = ""   // 验证 key（一次一用，verify 即销毁）
    @State private var aesKey = ""       // 轨迹加密密钥（16 字符）
    @State private var aesIv = ""        // 轨迹加密 IV（16 字符）
    @State private var loading = true    // generate 进行中
    @State private var verifying = false // verify 进行中
    @State private var msg = ""          // 失败提示文案（后端 msg 直显）

    // ---- 拖动状态 ----
    @State private var dragX: CGFloat = 0            // 滑块当前位移
    @State private var trajectory: [[Double]] = []   // 轨迹点 [ [x,y,t]... ]（与 web 端同构）
    @State private var dragStart = Date()            // 拖动起始时刻（算 total_time）
    @State private var yBase: CGFloat = 0            // 手势基准 y（上报加噪声防"Y 恒定=脚本"误判）

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("安全验证").font(.system(size: 16, weight: .semibold)).foregroundColor(T.textMain)
                Spacer()
                Button("关闭") {
                    if !verifying { onClosed() }
                }
                .font(.system(size: 13)).foregroundColor(T.textSub)
            }
            .padding(16)

            VStack(spacing: 14) {
                if loading {                                        // generate 中：
                    ProgressView().tint(T.primary)
                    Text("正在加载验证组件…").font(.system(size: 12)).foregroundColor(T.textSub).padding(.top, 8)
                } else {                                            // 就绪：
                    Text("拖动滑块到最右侧完成验证")                 // 交互提示
                        .font(.system(size: 13)).foregroundColor(T.textSub)
                    // 轨道
                    GeometryReader { g in
                        let maxMove = max(g.size.width - 48, 1)     // 最大位移 = 轨道宽 - 滑块宽
                        ZStack(alignment: .leading) {
                            // 轨道底
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.stroke, lineWidth: 1))
                            // 已拖过区域（渐变，宽度随拖动）
                            RoundedRectangle(cornerRadius: 12)
                                .fill(T.grad.opacity(0.35))
                                .frame(width: dragX + 48)
                            // 提示文案（未拖动时居中显示）
                            if dragX < 4 {
                                Text("向右拖动滑块").font(.system(size: 12)).foregroundColor(T.textSub)
                                    .frame(maxWidth: .infinity)
                            }
                            // 滑块把手
                            RoundedRectangle(cornerRadius: 12)
                                .fill(T.grad)
                                .frame(width: 48, height: 48)
                                .overlay(Image(systemName: "chevron.right.2").font(.system(size: 15, weight: .bold)).foregroundColor(T.bg))
                                .offset(x: dragX)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { v in          // 拖动中：更新位移+采轨迹
                                            if trajectory.isEmpty {             // 首点：记录起点
                                                dragStart = Date()
                                                yBase = v.location.y
                                            }
                                            dragX = min(max(0, v.translation.width), maxMove)  // 钳位位移
                                            let t = Date().timeIntervalSince(dragStart) * 1000  // 相对时间 ms
                                            // x/y 加微噪声上报：真手指不会完美水平（后端"Y 恒定/X 增量恒定"判脚本）
                                            let xn = Double(dragX) + Double.random(in: -1.0...1.0)
                                            let yn = Double(yBase) + Double.random(in: -3.0...3.0)
                                            trajectory.append([xn, yn, t])
                                        }
                                        .onEnded { _ in            // 松手：本地预判后上送验证
                                            Task { await verify(maxMove: maxMove) }
                                        }
                                )
                        }
                    }
                    .frame(height: 48)
                    if !msg.isEmpty {                               // 失败提示
                        Text(msg).font(.system(size: 12)).foregroundColor(T.danger)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 20)

            if verifying {                                          // 校验中：
                HStack(spacing: 8) {
                    ProgressView().tint(T.primary)
                    Text("正在校验…").font(.system(size: 12)).foregroundColor(T.textSub)
                }
                .padding(.top, 10)
            }
            Spacer(minLength: 8)
        }
        .presentationDetentsCompat()
        .background(Color(hex: "0D1420"))
        .task { await refresh() }                                   // 出现即取验证会话
    }

    /// 拉取新验证会话：GET captcha/slider/generate → captcha_key + AES 密钥/IV
    private func refresh() async {
        await MainActor.run {
            loading = true; msg = ""
            dragX = 0; trajectory = []
        }
        do {
            let d = try await Network.get("captcha/slider/generate")
            let k = d["captcha_key"].str ?? ""
            guard !k.isEmpty else { throw ApiError.business("获取验证码失败") }
            await MainActor.run {
                captchaKey = k
                aesKey = d["aes_key"].str ?? ""
                aesIv = d["aes_iv"].str ?? ""
                loading = false
            }
        } catch {
            await MainActor.run {
                loading = false
                msg = (error as? ApiError)?.errorDescription ?? "获取验证码失败"
            }
        }
    }

    /// 松手上送：ratio 预判 → 构造轨迹载荷 → AES-CBC 加密 → POST captcha/slider/verify
    private func verify(maxMove: CGFloat) async {
        guard !verifying, !captchaKey.isEmpty else { return }
        let ratio = maxMove > 0 ? Double(dragX / maxMove) : 0       // 归一化比例（拖满=1.0）
        guard ratio >= 0.80 else {                                  // 服务端目标 0.88~0.98 容差 0.08：
            await MainActor.run {
                msg = "请将滑块拖动到最右侧"                          // 不足 0.80 必拒，省一次接口
                trajectory = []; dragX = 0
            }
            return
        }
        await MainActor.run { verifying = true }
        defer { Task { await MainActor.run { verifying = false } } }
        // 载荷（与 web 端同构）：ratio/total_time/trajectory/pause_count/point_count/mouse_down_count
        let realMs = Int(Date().timeIntervalSince(dragStart) * 1000)
        let totalTime = max(realMs, 600)                            // 快甩 <500ms 会被"操作过快"拒，补足下限
        let payload: [String: Any] = [
            "ratio": (ratio * 10000).rounded() / 10000,             // 四位小数（对齐 web）
            "total_time": totalTime,
            "trajectory": trajectory,
            "pause_count": 0,
            "point_count": trajectory.count,
            "mouse_down_count": 1,
        ]
        guard let jd = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jd, encoding: .utf8),
              let cipher = Crypto.aesCBCEncryptBase64(jsonStr, key: aesKey, iv: aesIv) else {
            await MainActor.run { msg = "轨迹加密失败，请重试" }
            return
        }
        do {
            let d = try await Network.post("captcha/slider/verify", body: [
                "captcha_key": captchaKey,
                "payload": cipher,
            ])
            let token = d["slider_token"].str ?? ""
            guard !token.isEmpty else { throw ApiError.business("验证失败，请重试") }
            onVerified(token)                                       // 成功：回传 token
        } catch {                                                   // 失败：提示 + 0.8s 后自动换新会话重试
            let m = (error as? ApiError)?.errorDescription ?? "验证失败，请重试"
            await MainActor.run { msg = m }
            try? await Task.sleep(nanoseconds: 800_000_000)
            await refresh()
        }
    }
}

/// iOS 15 兼容 sheet 高度
extension View {
    @ViewBuilder
    func presentationDetentsCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.height(300)])
        } else {
            self
        }
    }
}
