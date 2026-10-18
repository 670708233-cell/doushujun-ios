import SwiftUI

// ============================================================================
// LoginView —— 登录页（App 门面，科技感重点页）
// 账号密码（web 端同款）+ 图形验证码 + 滑块验证 + 注册/找回入口 + 微信登录占位
// ============================================================================

struct LoginView: View {
    // MARK: - 全局状态

    @EnvironmentObject private var store: UserStore   // 全局用户状态（登录成功写入）

    // MARK: - 页面状态

    @State private var account = ""                   // 账号（用户名/邮箱）
    @State private var password = ""                  // 密码
    @State private var captchaCode = ""               // 图形验证码输入
    @State private var captcha: API.CaptchaImage?     // 服务端图形验证码（key+base64图）
    @State private var sliderToken = ""               // 滑块验证通过后的 token
    @State private var sliderRefreshID = UUID()       // 滑块组件重挂载 ID（失败后强制刷新）
    @State private var isLoading = false              // 登录请求进行中
    @State private var errorMessage = ""              // 错误提示
    @State private var showRegister = false           // 注册页弹窗
    @State private var showReset = false              // 找回密码弹窗
    @State private var showWechatTip = false          // 微信登录提示弹窗

    // 入场动画状态（onAppear 后触发）
    @State private var logoShown = false              // Logo 淡入+缩放
    @State private var cardShown = false              // 表单卡上移淡入

    var body: some View {
        ZStack {
            // 第一层：深空赛博背景（光斑+网格）
            CyberBackground()

            // 第二层：可滚动内容
            ScrollView {
                VStack(spacing: 22) {

                    // ---- 品牌区：六边形 Logo + 渐变标题 + 副标题 ----
                    VStack(spacing: 12) {
                        HexLogo(size: 84)                          // 科技六边形 Logo
                            .scaleEffect(logoShown ? 1 : 0.6)      // 入场：从 60% 缩放弹出
                            .opacity(logoShown ? 1 : 0)            // 入场：透明→不透明
                        VStack(spacing: 6) {
                            Text("抖数君")                          // 品牌名
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .gradientText(Theme.cyber)          // 青蓝紫流光渐变字
                            Text("AI 数据分析 · 查权重 · 查作品 · 会员充值") // 一句话说明
                                .font(.system(size: 12.5))
                                .foregroundColor(Theme.textSub)
                                .tracking(1)                        // 字距放宽更精致
                        }
                    }
                    .padding(.top, 48)

                    // ---- 登录表单玻璃卡 ----
                    VStack(spacing: 16) {

                        // 卡片标题行
                        SectionHeader(icon: "person.badge.key.fill", title: "账号登录")

                        // 账号输入框（聚焦发光）
                        CyberField(icon: "person.fill",
                                   placeholder: "用户名 / 邮箱",
                                   text: $account,
                                   keyboard: .emailAddress)

                        // 密码输入框
                        CyberField(icon: "lock.fill",
                                   placeholder: "密码",
                                   text: $password,
                                   secure: true)

                        // 图形验证码行：输入框 + 验证码图（点击刷新）
                        HStack(spacing: 10) {
                            CyberField(icon: "shield.lefthalf.filled",
                                       placeholder: "图形验证码",
                                       text: $captchaCode)
                                .frame(maxWidth: .infinity)          // 撑满剩余宽度
                            // 验证码图：白底（验证码本身是浅色图）+ 圆角 + 可点击
                            captchaImage
                                .frame(width: 112, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.cardStroke, lineWidth: 1)
                                )
                                .onTapGesture { Task { await loadCaptcha() } } // 点击换一张
                        }

                        // 滑块验证（验证通过回调写入 sliderToken）
                        SliderCaptchaView { token in
                            sliderToken = token
                        }
                        .id(sliderRefreshID)                          // ID 变化=强制重建刷新

                        // 错误提示条（有错误才显示）
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill") // 警告图标
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.red)
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.red)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.10)))
                        }

                        // 登录按钮：霓虹渐变发光主按钮
                        Button {
                            Task { await doLogin() }                  // 点击发起登录
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)       // 加载中转圈
                                } else {
                                    Image(systemName: "arrow.right.circle.fill") // 箭头图标
                                    Text("登 录")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.hero, height: 52))
                        .disabled(isLoading || sliderToken.isEmpty)   // 未过滑块/请求中禁用

                        // 未完成滑块的引导提示
                        if sliderToken.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.point.up.left.fill") // 手势提示图标
                                    .font(.system(size: 12))
                                Text("请先完成滑块验证")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Theme.amber)
                        }
                    }
                    .glassCard(radius: 22, padding: 18)               // 玻璃卡片外观
                    .opacity(cardShown ? 1 : 0)                       // 入场淡入
                    .offset(y: cardShown ? 0 : 28)                    // 入场上移
                    .padding(.horizontal, 22)

                    // ---- 微信授权登录（描边玻璃次按钮，占位）----
                    Button {
                        showWechatTip = true                          // 弹提示
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.circle.fill")  // 聊天气泡图标
                                .font(.system(size: 17))
                            Text("微信授权登录")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.green.opacity(0.14))       // 绿色淡底
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.green.opacity(0.55), lineWidth: 1.2) // 绿色描边
                        )
                    }
                    .padding(.horizontal, 22)

                    // ---- 注册 / 找回密码：渐变文字链接 ----
                    HStack(spacing: 32) {
                        Button {
                            showRegister = true                        // 打开注册
                        } label: {
                            Text("注册新账号")
                                .font(.system(size: 14, weight: .medium))
                                .gradientText(Theme.cyber)             // 渐变链接字
                        }
                        // 中间分隔点
                        Circle().frame(width: 3, height: 3).foregroundColor(Theme.textDim)
                        Button {
                            showReset = true                           // 打开找回密码
                        } label: {
                            Text("找回密码")
                                .font(.system(size: 14, weight: .medium))
                                .gradientText(Theme.cyber)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)                                    // 隐藏导航栏（沉浸式）
        // 入场动画触发：logo 先弹，卡片 0.15s 后跟进
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { logoShown = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.15)) { cardShown = true }
        }
        // 微信登录占位提示弹窗
        .alert("微信授权登录", isPresented: $showWechatTip) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("微信授权登录即将开放，请先使用账号密码登录\n（与抖数君网页版账号通用）")
        }
        // 首次进入加载图形验证码
        .task {
            if captcha == nil { await loadCaptcha() }
        }
        // 注册弹窗（关闭后刷新验证码，防止旧码失效）
        .sheet(isPresented: $showRegister, onDismiss: { Task { await loadCaptcha() } }) {
            RegisterView()
        }
        // 找回密码弹窗（关闭后刷新验证码）
        .sheet(isPresented: $showReset, onDismiss: { Task { await loadCaptcha() } }) {
            ResetPasswordView()
        }
    }

    // MARK: - 图形验证码图

    @ViewBuilder
    private var captchaImage: some View {
        if let cap = captcha,                                        // 有验证码
           let data = Data(base64Encoded: cleanBase64(cap.base64Image)), // base64 解码成功
           let ui = UIImage(data: data) {                            // 转图片成功
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .background(Color.white)                             // 白底衬托浅色验证码
        } else {
            // 加载中/失败占位：暗底 + 「点击刷新」
            ZStack {
                Rectangle().fill(Color.white.opacity(0.06))
                Text("点击刷新")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    /// 去掉 dataURL 前缀（服务端返回 "data:image/png;base64,xxx"）
    private func cleanBase64(_ s: String) -> String {
        var t = s
        if let r = t.range(of: "base64,") {                          // 找到前缀结束位置
            t = String(t[r.upperBound...])                           // 截取纯 base64
        }
        return t
    }

    // MARK: - 网络动作

    /// 拉取新图形验证码
    private func loadCaptcha() async {
        errorMessage = ""
        do {
            captcha = try await API.generateCaptcha()                // GET /captcha/generate
            captchaCode = ""                                         // 清空已输入的旧码
        } catch {
            errorMessage = "验证码加载失败：\(error.localizedDescription)"
        }
    }

    /// 执行登录（校验 → API → 写入全局状态 → 失败刷新验证链）
    private func doLogin() async {
        errorMessage = ""
        // ---- 表单校验 ----
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
            // 调用登录接口（web 端 /user/login 同款参数）
            let data = try await API.login(username: account,
                                           password: password,
                                           captchaKey: cap.captchaKey,
                                           captchaCode: captchaCode,
                                           sliderToken: sliderToken)
            store.applyLogin(data: data)                             // 写 token/用户名/邮箱
            // 并行刷新余额与 VIP 状态
            async let _ = store.refreshBalance()
            async let _ = store.refreshVip()
        } catch {
            errorMessage = error.localizedDescription                 // 展示后端错误信息
            sliderToken = ""                                          // 清滑块 token
            sliderRefreshID = UUID()                                  // 强制重建滑块
            await loadCaptcha()                                       // 换新图形验证码
        }
    }
}
