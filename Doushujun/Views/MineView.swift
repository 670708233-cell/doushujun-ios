import SwiftUI  // UI 框架

/// 我的页（对齐安卓 MyScreen）：五 Tab 之一——用户卡（头像/余额/VIP）+ 五项菜单 + 退出登录
struct MineView: View {
    @ObservedObject private var bus = SessionBus.shared  // 观察总线（余额/等级变化即刷新）

    var onOpenVip: () -> Void        // 打开充值 VIP 弹层
    var onOpenInvite: () -> Void     // 打开邀请页
    var onOpenFeedback: () -> Void   // 打开反馈页
    var onLoggedOut: () -> Void      // 退出成功回调（切根视图）

    @State private var showChangePwd = false   // 修改密码弹层显隐
    @State private var confirmLogout = false   // 退出确认弹窗显隐
    @State private var snackbar = ""           // 底部提示

    var body: some View {
        ZStack {
            TechBackground()                             // 深空背景
            ScrollView(showsIndicators: false) {         // 滚动区
                VStack(spacing: 14) {
                    // 用户卡
                    GlassCard {
                        VStack(spacing: 14) {
                            HStack(spacing: 14) {        // 头像+信息横排
                                ZStack {                 // 渐变圆头像+首字母
                                    Circle().fill(T.grad).frame(width: 58, height: 58)   // 渐变底圆
                                    Text(String(bus.username.prefix(1).uppercased()))    // 用户名首字母大写
                                        .font(.system(size: 22, weight: .bold)).foregroundColor(T.bg)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {  // 名字+VIP 徽章
                                        Text(bus.username).font(.system(size: 18, weight: .bold)).foregroundColor(T.textMain)  // 用户名
                                        if bus.vipLevel != "免费用户" {    // 非 VIP 免费用户才显徽章：
                                            Text(bus.vipLevel)
                                                .font(.system(size: 10, weight: .bold)).foregroundColor(T.bg)
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .background(Capsule().fill(T.warn))   // 黄底徽章
                                        }
                                    }
                                    Text(bus.email).font(.system(size: 12)).foregroundColor(T.textSub)  // 邮箱
                                }
                                Spacer()
                            }
                            // 余额卡
                            HStack(spacing: 0) {         // 左余额右充值按钮
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("账户余额").font(.system(size: 11)).foregroundColor(T.textSub)  // 小标签
                                    Text(String(format: "%.2f", bus.balance))                            // 两位小数余额
                                        .font(.system(size: 26, weight: .heavy)).foregroundColor(T.primary)
                                }
                                Spacer()
                                Button(action: onOpenVip) {  // 充值入口
                                    Text("充值")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(T.bg)
                                        .padding(.horizontal, 22).padding(.vertical, 9)
                                        .background(Capsule().fill(T.grad))   // 渐变胶囊
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))  // 淡白内卡
                            if !bus.vipExpire.isEmpty {  // 有到期时间才显示行
                                InfoRow(label: "会员到期", value: String(bus.vipExpire.prefix(10)), valueColor: T.warn)  // 截日期部分
                            }
                        }
                    }

                    // 菜单
                    GlassCard(padding: 6) {
                        VStack(spacing: 0) {
                            menuRow(icon: "crown.fill", color: T.warn, title: "开通会员", desc: bus.vipLevel == "免费用户" ? "解锁更多查询次数" : "管理会员") { onOpenVip() }  // 会员菜单（文案按等级）
                            Divider().overlay(Color.white.opacity(0.05))       // 淡分隔线
                            menuRow(icon: "person.2.fill", color: T.primary, title: "邀请好友赚次数", desc: "双方各得奖励") { onOpenInvite() }  // 邀请菜单
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "bubble.left.fill", color: .green, title: "意见反馈", desc: "") { onOpenFeedback() }  // 反馈菜单
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "lock.fill", color: T.secondary, title: "修改密码", desc: "") { showChangePwd = true }  // 改密菜单（弹层）
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "arrow.down.circle.fill", color: .orange, title: "检查更新", desc: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")") {  // 版本号随包显示
                                AppUpdater.shared.checkOnLaunch()   // 手动触发更新检查
                                snackbar = "已在后台检查更新"          // 提示已触发
                            }
                        }
                    }

                    // 退出
                    Button {
                        confirmLogout = true                        // 弹确认框
                    } label: {
                        Text("退出登录")
                            .font(.system(size: 15, weight: .medium)).foregroundColor(T.danger)  // 红字
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(T.danger.opacity(0.10)))   // 红淡底
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.danger.opacity(0.3), lineWidth: 1))  // 红描边
                    }

                    Text("抖数君 · AI作品分析建议优化平台")   // 底部 slogan
                        .font(.system(size: 11)).foregroundColor(T.textSub.opacity(0.6))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)                    // 左右留白
                .padding(.bottom, 30)                        // 底部留白
            }
        }
        .snackbar($snackbar)                                 // 底部提示
        .onAppear { bus.refreshAccount() }                   // 进页刷新账号（余额/VIP/配额）
        .sheet(isPresented: $showChangePwd) {                // 改密弹层
            ChangePwdSheet { snackbar = "密码修改成功" }      // 完成回调提示
        }
        .alert("退出登录", isPresented: $confirmLogout) {     // 退出确认
            Button("取消", role: .cancel) {}                 // 取消不动
            Button("退出", role: .destructive) {             // 确认退出：
                bus.doLogout()                               // 清令牌切登录页
                onLoggedOut()                                // 通知根视图
            }
        } message: {
            Text("确定退出当前账号吗？")                       // 确认文案
        }
    }

    /// 菜单行：彩色图标+标题描述+右箭头
    private func menuRow(icon: String, color: Color, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {                            // 图标+文字+箭头
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)  // 图标
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)))  // 同色淡底块
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15)).foregroundColor(T.textMain)   // 标题
                    if !desc.isEmpty { Text(desc).font(.system(size: 11)).foregroundColor(T.textSub) }  // 描述（可选）
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)  // 右箭头
            }
            .padding(.vertical, 10)                          // 行内边距
        }
    }
}

/// 修改密码弹层：三密码框+校验+提交
struct ChangePwdSheet: View {
    var onDone: () -> Void                          // 成功回调
    @Environment(\.dismiss) private var dismiss     // 弹层关闭

    @State private var oldPwd = ""                  // 当前密码
    @State private var newPwd = ""                  // 新密码
    @State private var confirmPwd = ""              // 确认新密码
    @State private var loading = false              // 提交中
    @State private var error = ""                   // 错误文案

    var body: some View {
        ZStack {
            TechBackground()                        // 深空背景
            VStack(spacing: 16) {
                HStack {                            // 标题+关闭
                    Text("修改密码").font(.system(size: 17, weight: .bold)).foregroundColor(T.textMain)
                    Spacer()
                    Button { dismiss() } label: {   // 右上角关闭
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(T.textSub)
                    }
                }
                GlassCard {                         // 表单卡
                    VStack(alignment: .leading, spacing: 12) {
                        DSJField(placeholder: "当前密码", text: $oldPwd, secure: true)          // 旧密码（密文）
                        DSJField(placeholder: "新密码（至少6位）", text: $newPwd, secure: true)  // 新密码
                        DSJField(placeholder: "确认新密码", text: $confirmPwd, secure: true)    // 确认
                        ErrorText(text: error)          // 错误红字
                        PrimaryButton(title: "确认修改", loading: loading) { submit() }  // 提交按钮
                    }
                }
                Spacer()                            // 靠顶
            }
            .padding(18)                            // 内边距
        }
    }

    /// 提交：三重本地校验 → POST user/change-password → 回调+关闭
    private func submit() {
        guard !oldPwd.isEmpty else { error = "请输入当前密码"; return }        // 旧密码非空
        guard newPwd.count >= 6 else { error = "新密码至少6位"; return }       // 新密码长度
        guard newPwd == confirmPwd else { error = "两次输入的新密码不一致"; return }  // 一致性
        loading = true                        // 进入提交态
        error = ""                            // 清错误
        Task {                                // 后台提交
            defer { loading = false }         // 退出提交态
            do {
                _ = try await Network.post("user/change-password", body: [   // 上送双密码
                    "old_password": oldPwd, "new_password": newPwd,
                ])
                await MainActor.run {             // 主线程收尾
                    onDone()                      // 通知成功
                    dismiss()                     // 关弹层
                }
            } catch {                             // 失败：
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "修改失败" }  // 展示原因
            }
        }
    }
}
