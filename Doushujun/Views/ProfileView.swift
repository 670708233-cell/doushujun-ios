import SwiftUI

// ============================================================================
// ProfileView —— 我的（用户卡 + VIP 信息 + 账户操作 + 退出登录）
// 内嵌 ChangePasswordView 修改密码弹窗
// ============================================================================

struct ProfileView: View {

    @EnvironmentObject private var store: UserStore   // 全局状态

    // MARK: - 状态

    @State private var toast: String?                 // 轻提示
    @State private var showLogoutConfirm = false      // 退出确认弹窗
    @State private var showChangePassword = false     // 修改密码弹窗
    @State private var appeared = false               // 入场动画

    var body: some View {
        ZStack {
            CyberBackground()                              // 统一深空背景

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 用户信息卡 ----
                    VStack(spacing: 14) {
                        // 渐变圆头像（取用户名首字）
                        ZStack {
                            Circle()
                                .fill(Theme.hero)                  // 蓝紫渐变底
                                .frame(width: 76, height: 76)
                                .shadow(color: Theme.purple.opacity(0.5), radius: 16, y: 3) // 光晕
                            Text(String(store.username.isEmpty ? "抖" : Array(store.username)[0]))
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1.5)) // 高光描边

                        // 用户名 + 邮箱
                        Text(store.username.isEmpty ? "-" : store.username)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textMain)
                        Text(store.email)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.textSub)

                        // 徽章行：VIP + 余额
                        HStack(spacing: 10) {
                            let vip = store.vipStatus
                            // VIP 徽章（金色/灰色）
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill").font(.system(size: 10))
                                Text(vip?.isVip == true ? "VIP · \(vip?.packageName ?? "")" : "普通用户")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(vip?.isVip == true ? Theme.amber : Theme.textSub)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(vip?.isVip == true ? Theme.amber.opacity(0.14) : Color.white.opacity(0.06)))
                            .overlay(Capsule().stroke(vip?.isVip == true ? Theme.amber.opacity(0.5) : Theme.cardStroke, lineWidth: 1))

                            // 余额徽章（绿色）
                            HStack(spacing: 4) {
                                Image(systemName: "creditcard.fill").font(.system(size: 10))
                                Text("¥\(String(format: "%.2f", store.balance))")
                            }
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.green)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.green.opacity(0.12)))
                            .overlay(Capsule().stroke(Theme.green.opacity(0.4), lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassCard(radius: 22, padding: 18)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // ---- VIP 信息卡（是 VIP 才显示）----
                    if store.vipStatus?.isVip == true {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(icon: "crown.fill", title: "会员信息")
                            infoRow(label: "套餐", value: store.vipStatus?.packageName ?? "-")
                            infoRow(label: "剩余", value: store.vipStatus?.remainText ?? "-")
                            infoRow(label: "有效期",
                                    value: "\(store.vipStatus?.startTime ?? "-") 至 \(store.vipStatus?.isPermanent == true ? "永久" : (store.vipStatus?.endTime ?? "-"))")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 22, padding: 18)
                        .padding(.horizontal, 18)
                    }

                    // ---- 账户操作卡 ----
                    VStack(spacing: 0) {
                        actionRow(icon: "arrow.clockwise", title: "刷新账户信息",
                                  tint: Theme.cyan) {
                            // 并行刷新余额 + VIP，完成提示
                            Task {
                                async let a = store.refreshBalance()
                                async let b = store.refreshVip(showLoading: true)
                                _ = await (a, b)
                                showToast("已刷新")
                            }
                        }
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 54)
                        actionRow(icon: "lock.rotation", title: "修改密码",
                                  tint: Theme.blue) {
                            showChangePassword = true              // 打开修改弹窗
                        }
                    }
                    .glassCard(radius: 22, padding: 4)
                    .padding(.horizontal, 18)

                    // ---- 退出登录（霓虹红描边按钮）----
                    Button {
                        showLogoutConfirm = true                    // 二次确认
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right") // 登出图标
                            Text("退出登录")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.red.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.red.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.horizontal, 18)

                    Spacer().frame(height: 20)
                }
            }
        }
        .navigationBarHidden(true)
        .opacity(appeared ? 1 : 0)                                 // 入场淡入
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        // 退出确认
        .confirmationDialog("确定退出当前账号？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { store.logout() }
            Button("取消", role: .cancel) {}
        }
        // 修改密码弹窗（完成回调提示）
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView { msg in showToast(msg) }
        }
        .overlay(toastView)
    }

    // MARK: - 小部件

    @ViewBuilder
    private var toastView: some View {
        if let msg = toast {
            VStack {
                Spacer()
                Text(msg)
                    .font(.system(size: 13.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardStroke, lineWidth: 1))
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

    /// 信息行：左标签右值
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundColor(Theme.textSub)
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textMain)
        }
    }

    /// 操作行：彩色图标 + 标题 + 箭头
    private func actionRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标淡底小方块
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundColor(tint)
                    )
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textMain)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textDim)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// ============================================================================
// ChangePasswordView —— 修改密码弹窗（旧密码 + 新密码 + 确认）
// ============================================================================

struct ChangePasswordView: View {

    @Environment(\.dismiss) private var dismiss       // 关闭
    var onDone: (String) -> Void                      // 成功回调（上层 toast）

    @State private var oldPassword = ""               // 旧密码
    @State private var newPassword = ""               // 新密码
    @State private var confirmPassword = ""           // 确认新密码
    @State private var isLoading = false              // 提交中
    @State private var errorMessage = ""              // 错误提示

    var body: some View {
        ZStack {
            CyberBackground()

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 顶部标题栏 ----
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.textMain)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.07)))
                                .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                        }
                        Spacer()
                        Text("修改密码")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .gradientText(Theme.cyber)
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // ---- 表单玻璃卡 ----
                    VStack(spacing: 14) {
                        SectionHeader(icon: "key.fill", title: "设置新密码")

                        CyberField(icon: "lock.fill", placeholder: "旧密码", text: $oldPassword, secure: true)
                        CyberField(icon: "lock.open.fill", placeholder: "新密码（不少于6位）", text: $newPassword, secure: true)
                        CyberField(icon: "lock.shield.fill", placeholder: "确认新密码", text: $confirmPassword, secure: true)

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

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("确认修改")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.hero))
                        .disabled(isLoading)
                    }
                    .glassCard(radius: 22, padding: 18)
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - 提交

    private func submit() async {
        errorMessage = ""
        guard !oldPassword.isEmpty, !newPassword.isEmpty else {
            errorMessage = "请填写完整"; return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "新密码不少于 6 位"; return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await API.changePassword(oldPassword: oldPassword, newPassword: newPassword)
            dismiss()
            onDone("密码修改成功")                                   // 上层 toast
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
