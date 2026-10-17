import SwiftUI

/// 我的（余额 / VIP 状态 / 修改密码 / 退出登录）
struct ProfileView: View {
    @EnvironmentObject private var store: UserStore

    @State private var toast: String?
    @State private var showLogoutConfirm = false
    @State private var showChangePassword = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // 用户卡片
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                              Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            Text(String(store.username.isEmpty ? "抖" : Array(store.username)[0]))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(store.username.isEmpty ? "-" : store.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(store.email)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))

                        HStack(spacing: 10) {
                            let vip = store.vipStatus
                            Text(vip?.isVip == true
                                 ? "VIP · \(vip?.packageName ?? "")"
                                 : "普通用户")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(vip?.isVip == true
                                                 ? Color(red: 1.0, green: 0.82, blue: 0.35)
                                                 : Color(red: 0.6, green: 0.66, blue: 0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((vip?.isVip == true
                                             ? Color(red: 1.0, green: 0.82, blue: 0.35)
                                             : Color.white).opacity(0.1))
                                .cornerRadius(12)
                            Text("余额 ¥\(String(format: "%.2f", store.balance))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.3, green: 0.75, blue: 0.42))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.3, green: 0.75, blue: 0.42).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // VIP 信息
                    if store.vipStatus?.isVip == true {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("会员信息")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            infoRow(label: "套餐", value: store.vipStatus?.packageName ?? "-")
                            infoRow(label: "剩余", value: store.vipStatus?.remainText ?? "-")
                            let period = "\(store.vipStatus?.startTime ?? "-") 至 \(store.vipStatus?.isPermanent == true ? "永久" : (store.vipStatus?.endTime ?? "-"))"
                            infoRow(label: "有效期", value: period)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                    }

                    // 功能列表
                    VStack(spacing: 0) {
                        actionRow(icon: "arrow.clockwise", title: "刷新账户信息") {
                            Task {
                                async let a = store.refreshBalance()
                                async let b = store.refreshVip(showLoading: true)
                                _ = await (a, b)
                                showToast("已刷新")
                            }
                        }
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                        actionRow(icon: "lock.rotation", title: "修改密码") {
                            showChangePassword = true
                        }
                    }
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // 退出登录
                    Button(action: { showLogoutConfirm = true }) {
                        Text("退出登录")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 20)
                }
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { store.logout() }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView { toast in
                showToast(toast)
            }
        }
        .overlay(toastView)
    }

    @ViewBuilder
    private var toastView: some View {
        if let msg = toast {
            VStack {
                Spacer()
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                Spacer().frame(height: 80)
            }
        }
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toast == msg { toast = nil }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.45, green: 0.5, blue: 0.62))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

/// 修改密码弹窗
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    var onDone: (String) -> Void

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

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
                        Text("修改密码")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    VStack(spacing: 14) {
                        field(placeholder: "旧密码", text: $oldPassword)
                        field(placeholder: "新密码（不少于6位）", text: $newPassword)
                        field(placeholder: "确认新密码", text: $confirmPassword)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: { Task { await submit() } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("确认修改")
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
    }

    private func field(placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .foregroundColor(.white)
            .padding(12)
            .background(Color(red: 0.11, green: 0.16, blue: 0.28))
            .cornerRadius(10)
    }

    private func submit() async {
        errorMessage = ""
        guard !oldPassword.isEmpty, !newPassword.isEmpty else {
            errorMessage = "请填写完整"
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "新密码不少于 6 位"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await API.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            dismiss()
            onDone("密码修改成功")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
