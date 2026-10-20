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
            GeeTestSheet { sliderToken in
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
            GeeTestSheet { sliderToken in
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

// MARK: - 极验 4.0 弹窗（WKWebView 本地 geetest.html）

struct GeeTestSheet: View {
    var onVerified: (String) -> Void   // 拿到 slider_token
    var onClosed: () -> Void

    @State private var captchaId: String? = nil
    @State private var loadError: String? = nil
    @State private var verifying = false
    @State private var reloadKey = 0   // 重建 WebView（重新验证）

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

            if let err = loadError {
                VStack(spacing: 12) {
                    Text(err).font(.system(size: 13)).foregroundColor(T.danger)
                        .multilineTextAlignment(.center)
                    Button("重新验证") {
                        loadError = nil
                        captchaId = nil
                        reloadKey += 1
                        Task { await loadConfig() }
                    }
                    .font(.system(size: 14, weight: .medium)).foregroundColor(T.primary)
                }
                .frame(height: 220)
            } else if captchaId == nil {
                VStack {
                    ProgressView().tint(T.primary)
                    Text("正在加载验证组件…").font(.system(size: 12)).foregroundColor(T.textSub).padding(.top, 8)
                }
                .frame(height: 300)
            } else {
                GeeTestWebView(captchaId: captchaId!, reloadKey: reloadKey,
                               onSuccess: { json in Task { await verify(json) } },
                               onClose: { onClosed() },
                               onError: { msg in loadError = msg })
                    .frame(height: 320)
            }

            if verifying {
                HStack(spacing: 8) {
                    ProgressView().tint(T.primary)
                    Text("正在校验…").font(.system(size: 12)).foregroundColor(T.textSub)
                }
                .padding(.bottom, 14)
            }
            Spacer(minLength: 8)
        }
        .presentationDetentsCompat()
        .background(Color(hex: "0D1420"))
        .task { await loadConfig() }
    }

    private func loadConfig() async {
        do {
            let d = try await Network.get("captcha/geetest/config")
            let id = d["captcha_id"].str ?? ""
            guard !id.isEmpty else { throw ApiError.business("获取验证配置失败") }
            await MainActor.run { captchaId = id }
        } catch ApiError.notFound {
            // 生产后端未部署极验接口（slider_token 本就可选）→ 跳过安全验证直接登录
            await MainActor.run { onVerified("") }
        } catch {
            await MainActor.run { loadError = (error as? ApiError)?.errorDescription ?? "获取验证配置失败" }
        }
    }

    /// POST captcha/geetest/verify：四元组 → slider_token
    private func verify(_ json: String) async {
        verifying = true
        defer { verifying = false }
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            loadError = "验证结果解析失败"
            return
        }
        do {
            let d = try await Network.post("captcha/geetest/verify", body: obj)
            let token = d["slider_token"].str ?? ""
            guard !token.isEmpty else { throw ApiError.business("验证失败，请重试") }
            onVerified(token)
        } catch {
            loadError = (error as? ApiError)?.errorDescription ?? "验证失败，请重试"
        }
    }
}

/// WKWebView 容器：loadFileURL 本地 html（替换 captcha_id），桥转发
struct GeeTestWebView: UIViewRepresentable {
    let captchaId: String
    let reloadKey: Int
    let onSuccess: (String) -> Void
    let onClose: () -> Void
    let onError: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(context.coordinator, name: "dsj")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = context.coordinator
        context.coordinator.webView = wv
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if context.coordinator.loadedKey != reloadKey {
            context.coordinator.loadedKey = reloadKey
            load(wv)
        }
    }

    private func load(_ wv: WKWebView) {
        // 读 bundle 里的 geetest.html → 替换 captcha_id → 写沙盒 → loadFileURL
        guard let url = Bundle.main.url(forResource: "geetest", withExtension: "html"),
              var html = try? String(contentsOf: url, encoding: .utf8) else {
            onError("验证组件缺失")
            return
        }
        html = html.replacingOccurrences(of: "__CAPTCHA_ID__", with: captchaId)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("geetest_run.html")
        try? html.write(to: tmp, atomically: true, encoding: .utf8)
        wv.loadFileURL(tmp, allowingReadAccessTo: FileManager.default.temporaryDirectory)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: GeeTestWebView
        var webView: WKWebView?
        var loadedKey = -1

        init(_ p: GeeTestWebView) { parent = p }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
            DispatchQueue.main.async {
                switch event {
                case "onCaptchaSuccess":
                    if let data = body["data"] as? String { self.parent.onSuccess(data) }
                case "onClose":
                    self.parent.onClose()
                case "onError":
                    self.parent.onError(body["data"] as? String ?? "验证出错，请重试")
                default: break
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onError("页面加载失败：\(error.localizedDescription)")
        }
    }
}

/// iOS 15 兼容 sheet 高度
extension View {
    @ViewBuilder
    func presentationDetentsCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.height(420)])
        } else {
            self
        }
    }
}
