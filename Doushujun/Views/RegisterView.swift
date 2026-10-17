import SwiftUI

/// 注册页（web 端同款：用户名/邮箱/密码/邀请码 + 图形验证码 + 邮箱验证码）
struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var inviteCode = ""
    @State private var captchaCode = ""
    @State private var emailCode = ""

    @State private var captcha: API.CaptchaImage?
    @State private var info: RegisterInfo?
    @State private var isLoading = false
    @State private var sendingCode = false
    @State private var countdown = 0
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text("注册新账号")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if let inf = info, !inf.allowRegister {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.3))
                            Text("当前未开放注册")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        formCard
                    }
                }
            }
        }
        .task {
            async let c: Void = loadCaptcha()
            async let i: Void = loadInfo()
            _ = await (c, i)
        }
        .onDisappear { timer?.invalidate() }
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            field(icon: "person", placeholder: "用户名", text: $username)
            field(icon: "envelope", placeholder: "邮箱", text: $email)
                .keyboardType(.emailAddress)
            field(icon: "lock", placeholder: "密码（不少于6位）", text: $password, secure: true)
            field(icon: "lock.fill", placeholder: "确认密码", text: $confirmPassword, secure: true)
            field(icon: "gift", placeholder: "邀请码（选填）", text: $inviteCode)

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

            // 邮箱验证码
            HStack(spacing: 10) {
                TextField("邮箱验证码", text: $emailCode)
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                    .cornerRadius(10)
                Button(action: { Task { await sendCode() } }) {
                    Text(sendingCode ? "发送中" : (countdown > 0 ? "\(countdown)s 后重发" : "获取验证码"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(countdown > 0
                                         ? Color(red: 0.5, green: 0.6, blue: 0.8)
                                         : Color(red: 0.4, green: 0.55, blue: 1.0))
                        .frame(width: 110, height: 44)
                        .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                        .cornerRadius(10)
                }
                .disabled(sendingCode || countdown > 0)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !successMessage.isEmpty {
                Text(successMessage)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.3, green: 0.75, blue: 0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: { Task { await doRegister() } }) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("注 册")
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
            .disabled(isLoading)

            if let inf = info, inf.newUserBonus > 0 {
                Text("新用户注册赠送 \(String(format: "%.2f", inf.newUserBonus)) 元余额")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.3))
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.8))
                .frame(width: 24)
            if secure {
                SecureField(placeholder, text: text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color(red: 0.11, green: 0.16, blue: 0.28))
        .cornerRadius(10)
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
        do {
            captcha = try await API.generateCaptcha()
            captchaCode = ""
        } catch {
            errorMessage = "验证码加载失败"
        }
    }

    private func loadInfo() async {
        info = try? await API.fetchRegisterInfo()
    }

    private func sendCode() async {
        errorMessage = ""
        successMessage = ""
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "请输入正确的邮箱地址"
            return
        }
        guard let cap = captcha, !cap.captchaKey.isEmpty, !captchaCode.isEmpty else {
            errorMessage = "请先输入图形验证码"
            return
        }
        sendingCode = true
        defer { sendingCode = false }
        do {
            try await API.sendEmailCode(userEmail: email,
                                        captchaKey: cap.captchaKey,
                                        captchaCode: captchaCode)
            successMessage = "验证码已发送，请查收邮箱"
            countdown = 60
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                Task { @MainActor in
                    countdown -= 1
                    if countdown <= 0 { t.invalidate() }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            await loadCaptcha()
        }
    }

    private func doRegister() async {
        errorMessage = ""
        successMessage = ""
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "请填写完整信息"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "密码不少于 6 位"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        guard let cap = captcha, !cap.captchaKey.isEmpty, !captchaCode.isEmpty else {
            errorMessage = "请输入图形验证码"
            return
        }
        guard !emailCode.isEmpty else {
            errorMessage = "请输入邮箱验证码"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await API.register(username: username, email: email, password: password,
                                   emailCode: emailCode, captchaKey: cap.captchaKey,
                                   captchaCode: captchaCode)
            successMessage = "注册成功，请返回登录"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            await loadCaptcha()
        }
    }
}
