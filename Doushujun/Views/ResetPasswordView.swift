import SwiftUI

/// 找回密码（web 端同款：邮箱 + 验证码 + 新密码）
struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var emailCode = ""
    @State private var newPassword = ""

    @State private var sendingCode = false
    @State private var countdown = 0
    @State private var isLoading = false
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
                        Text("找回密码")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    VStack(spacing: 14) {
                        Text("输入注册邮箱，通过邮箱验证码重置密码")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        field(icon: "envelope", placeholder: "注册邮箱", text: $email)
                            .keyboardType(.emailAddress)

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

                        field(icon: "lock", placeholder: "新密码（不少于6位）", text: $newPassword, secure: true)

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

                        Button(action: { Task { await doReset() } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("重置密码")
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
                    }
                    .padding(18)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)
                }
            }
        }
        .onDisappear { timer?.invalidate() }
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

    private func sendCode() async {
        errorMessage = ""
        successMessage = ""
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "请输入正确的邮箱地址"
            return
        }
        sendingCode = true
        defer { sendingCode = false }
        do {
            try await API.checkEmailForReset(email)
            try await API.sendResetCode(email)
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
        }
    }

    private func doReset() async {
        errorMessage = ""
        successMessage = ""
        guard !email.isEmpty, !emailCode.isEmpty else {
            errorMessage = "请填写邮箱和验证码"
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "新密码不少于 6 位"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await API.resetPassword(email: email, emailCode: emailCode, newPassword: newPassword)
            successMessage = "密码重置成功，请返回使用新密码登录"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
