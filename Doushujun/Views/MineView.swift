import SwiftUI

/// 我的页（对齐安卓 MyScreen）
struct MineView: View {
    @ObservedObject private var bus = SessionBus.shared

    var onOpenVip: () -> Void
    var onOpenInvite: () -> Void
    var onOpenFeedback: () -> Void
    var onLoggedOut: () -> Void

    @State private var showChangePwd = false
    @State private var confirmLogout = false
    @State private var snackbar = ""

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // 用户卡
                    GlassCard {
                        VStack(spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(T.grad).frame(width: 58, height: 58)
                                    Text(String(bus.username.prefix(1).uppercased()))
                                        .font(.system(size: 22, weight: .bold)).foregroundColor(T.bg)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(bus.username).font(.system(size: 18, weight: .bold)).foregroundColor(T.textMain)
                                        if bus.vipLevel != "免费用户" {
                                            Text(bus.vipLevel)
                                                .font(.system(size: 10, weight: .bold)).foregroundColor(T.bg)
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .background(Capsule().fill(T.warn))
                                        }
                                    }
                                    Text(bus.email).font(.system(size: 12)).foregroundColor(T.textSub)
                                }
                                Spacer()
                            }
                            // 余额卡
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("账户余额").font(.system(size: 11)).foregroundColor(T.textSub)
                                    Text(String(format: "%.2f", bus.balance))
                                        .font(.system(size: 26, weight: .heavy)).foregroundColor(T.primary)
                                }
                                Spacer()
                                Button(action: onOpenVip) {
                                    Text("充值")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(T.bg)
                                        .padding(.horizontal, 22).padding(.vertical, 9)
                                        .background(Capsule().fill(T.grad))
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                            if !bus.vipExpire.isEmpty {
                                InfoRow(label: "会员到期", value: String(bus.vipExpire.prefix(10)), valueColor: T.warn)
                            }
                        }
                    }

                    // 菜单
                    GlassCard(padding: 6) {
                        VStack(spacing: 0) {
                            menuRow(icon: "crown.fill", color: T.warn, title: "开通会员", desc: bus.vipLevel == "免费用户" ? "解锁更多查询次数" : "管理会员") { onOpenVip() }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "person.2.fill", color: T.primary, title: "邀请好友赚次数", desc: "双方各得奖励") { onOpenInvite() }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "bubble.left.fill", color: .green, title: "意见反馈", desc: "") { onOpenFeedback() }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "lock.fill", color: T.secondary, title: "修改密码", desc: "") { showChangePwd = true }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "arrow.down.circle.fill", color: .orange, title: "检查更新", desc: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")") {
                                AppUpdater.shared.checkOnLaunch()
                                snackbar = "已在后台检查更新"
                            }
                        }
                    }

                    // 退出
                    Button {
                        confirmLogout = true
                    } label: {
                        Text("退出登录")
                            .font(.system(size: 15, weight: .medium)).foregroundColor(T.danger)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.danger.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.danger.opacity(0.3), lineWidth: 1))
                    }

                    Text("抖数君 · AI作品分析建议优化平台")
                        .font(.system(size: 11)).foregroundColor(T.textSub.opacity(0.6))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .snackbar($snackbar)
        .onAppear { bus.refreshAccount() }
        .sheet(isPresented: $showChangePwd) {
            ChangePwdSheet { snackbar = "密码修改成功" }
        }
        .alert("退出登录", isPresented: $confirmLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                bus.doLogout()
                onLoggedOut()
            }
        } message: {
            Text("确定退出当前账号吗？")
        }
    }

    private func menuRow(icon: String, color: Color, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15)).foregroundColor(T.textMain)
                    if !desc.isEmpty { Text(desc).font(.system(size: 11)).foregroundColor(T.textSub) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
            }
            .padding(.vertical, 10)
        }
    }
}

/// 修改密码弹层
struct ChangePwdSheet: View {
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var confirmPwd = ""
    @State private var loading = false
    @State private var error = ""

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 16) {
                HStack {
                    Text("修改密码").font(.system(size: 17, weight: .bold)).foregroundColor(T.textMain)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(T.textSub)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        DSJField(placeholder: "当前密码", text: $oldPwd, secure: true)
                        DSJField(placeholder: "新密码（至少6位）", text: $newPwd, secure: true)
                        DSJField(placeholder: "确认新密码", text: $confirmPwd, secure: true)
                        ErrorText(text: error)
                        PrimaryButton(title: "确认修改", loading: loading) { submit() }
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private func submit() {
        guard !oldPwd.isEmpty else { error = "请输入当前密码"; return }
        guard newPwd.count >= 6 else { error = "新密码至少6位"; return }
        guard newPwd == confirmPwd else { error = "两次输入的新密码不一致"; return }
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                _ = try await Network.post("user/change-password", body: [
                    "old_password": oldPwd, "new_password": newPwd,
                ])
                await MainActor.run {
                    onDone()
                    dismiss()
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "修改失败" }
            }
        }
    }
}
