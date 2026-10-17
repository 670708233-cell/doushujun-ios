import SwiftUI

/// 登录页（web 端同款账号密码 + 图形验证码 + 滑块验证）
struct LoginView: View {
    @EnvironmentObject private var store: UserStore

    @State private var account = ""
    @State private var password = ""
    @State private var captchaCode = ""
    @State private var captcha: API.CaptchaImage?
    @State private var sliderToken = ""
    @State private var sliderRefreshID = UUID()
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRegister = false
    @State private var showReset = false
    @State private var showWechatTip = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Logo
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                              Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 84, height: 84)
                            Text("抖")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("抖数君")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("查权重 · 查作品 · 会员充值")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                    }
                    .padding(.top, 46)

                    // 表单卡片
                    VStack(spacing: 16) {
                        // 账号
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.8))
                                .frame(width: 24)
                            TextField("用户名 / 邮箱", text: $account)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                        .cornerRadius(10)

                        // 密码
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.8))
                                .frame(width: 24)
                            SecureField("密码", text: $password)
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                        .cornerRadius(10)

                        // 图形验证码
                        HStack(spacing: 10) {
                            TextField("图形验证码", text: $captchaCode)
                                .keyboardType(.asciiCapable)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                                .cornerRadius(10)
                            captchaImage
                                .frame(width: 110, height: 44)
                                .onTapGesture { Task { await loadCaptcha() } }
                        }

                        // 滑块验证
                        SliderCaptchaView { token in
                            sliderToken = token
                        }
                        .id(sliderRefreshID)

                        // 错误提示
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 登录按钮
                        Button(action: { Task { await doLogin() } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("登 录")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || sliderToken.isEmpty)

                        if sliderToken.isEmpty {
                            Text("请先完成滑块验证")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.3))
                        }
                    }
                    .padding(18)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    // 微信登录
                    Button(action: { showWechatTip = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 15))
                            Text("微信授权登录")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(red: 0.3, green: 0.75, blue: 0.42))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    // 注册 / 找回
                    HStack(spacing: 28) {
                        Button("注册新账号") { showRegister = true }
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                        Button("找回密码") { showReset = true }
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("微信授权登录", isPresented: $showWechatTip) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("微信授权登录即将开放，请先使用账号密码登录\n（与抖数君网页版账号通用）")
        }
        .task {
            if captcha == nil { await loadCaptcha() }
            if !store.isLoggedIn { return }
        }
        .sheet(isPresented: $showRegister, onDismiss: { Task { await loadCaptcha() } }) {
            RegisterView()
        }
        .sheet(isPresented: $showReset, onDismiss: { Task { await loadCaptcha() } }) {
            ResetPasswordView()
        }
    }

    @ViewBuilder
    private var captchaImage: some View {
        if let cap = captcha,
           let data = Data(base64Encoded: cleanBase64(cap.base64Image)),
           let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .background(Color.white)
                .cornerRadius(10)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.11, green: 0.16, blue: 0.28))
                Text("点击刷新")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.8))
            }
        }
    }

    private func cleanBase64(_ s: String) -> String {
        var t = s
        if let r = t.range(of: "base64,") {
            t = String(t[r.upperBound...])
        }
        return t
    }

    private func loadCaptcha() async {
        errorMessage = ""
        do {
            captcha = try await API.generateCaptcha()
            captchaCode = ""
        } catch {
            errorMessage = "验证码加载失败：\(error.localizedDescription)"
        }
    }

    private func doLogin() async {
        errorMessage = ""
        guard !account.isEmpty, !password.isEmpty else {
            errorMessage = "请输入账号和密码"
            return
        }
        guard let cap = captcha, !cap.captchaKey.isEmpty else {
            errorMessage = "请先获取图形验证码"
            return
        }
        guard !captchaCode.isEmpty else {
            errorMessage = "请输入图形验证码"
            return
        }
        guard !sliderToken.isEmpty else {
            errorMessage = "请先完成滑块验证"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await API.login(username: account,
                                           password: password,
                                           captchaKey: cap.captchaKey,
                                           captchaCode: captchaCode,
                                           sliderToken: sliderToken)
            store.applyLogin(data: data)
            async let _ = store.refreshBalance()
            async let _ = store.refreshVip()
        } catch {
            errorMessage = error.localizedDescription
            sliderToken = ""
            sliderRefreshID = UUID()
            await loadCaptcha()
        }
    }
}
