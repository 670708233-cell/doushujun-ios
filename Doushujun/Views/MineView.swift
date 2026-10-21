import SwiftUI      // UI 框架
import UIKit        // UIImage/UIGraphicsImageRenderer/JPEG 压缩（头像处理）
import PhotosUI     // 系统相册选择器（PhotosPicker，头像上传用）

/// 我的页（对齐安卓 MyScreen）：用户信息渐变横幅（头像/昵称可改）+ 邀请横幅 +
/// VIP 状态卡（到期/今日查询/套餐名/续费）+ 功能菜单两组 + 退出登录
struct MineView: View {
    @ObservedObject private var bus = SessionBus.shared  // 观察总线（余额/VIP/昵称变化即刷新）

    var onOpenVip: () -> Void        // 打开充值 VIP 弹层
    var onOpenInvite: () -> Void     // 打开邀请页
    var onOpenFeedback: () -> Void   // 打开反馈页
    var onLoggedOut: () -> Void      // 退出成功回调（切根视图）

    @State private var showChangePwd = false     // 修改密码弹层显隐
    @State private var confirmLogout = false     // 退出确认弹窗显隐
    @State private var showContact = false       // 联系客服弹窗显隐
    @State private var showNickEdit = false      // 昵称编辑弹窗显隐
    @State private var nickInput = ""            // 昵称编辑框内容（打开时预填当前值）
    @State private var nickSaving = false        // 昵称保存中（防重复提交）
    @State private var uploadingAvatar = false   // 头像上传中（头像圈遮罩转圈）
    @State private var pickedItem: PhotosPickerItem? = nil  // 相册选中项（onChange 触发上传）
    @State private var snackbar = ""             // 底部提示

    var body: some View {
        ZStack {
            TechBackground()                             // 深空背景
            ScrollView(showsIndicators: false) {         // 滚动区
                VStack(spacing: 14) {
                    userBanner                           // 用户信息渐变横幅（头像/昵称/邮箱）
                    inviteBanner                         // 邀请好友横幅
                    vipCard                              // 余额/会员状态卡
                    GlassCard(padding: 6) {              // 功能菜单组一
                        VStack(spacing: 0) {
                            menuRow(icon: "crown.fill", color: T.warn, title: "会员中心", desc: "套餐购买与支付") { onOpenVip() }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "lock.fill", color: T.secondary, title: "修改密码", desc: "账号密码管理") { showChangePwd = true }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "exclamationmark.bubble.fill", color: .green, title: "意见反馈", desc: "问题与建议") { onOpenFeedback() }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "headphones", color: .orange, title: "联系客服", desc: "微信号 doushujun01") { showContact = true }
                        }
                    }
                    GlassCard(padding: 6) {              // 功能菜单组二（协议/版本）
                        VStack(spacing: 0) {
                            menuRow(icon: "doc.text.fill", color: T.primary, title: "使用协议", desc: "") { snackbar = "使用协议敬请期待" }
                            Divider().overlay(Color.white.opacity(0.05))
                            menuRow(icon: "info.circle.fill", color: T.primary, title: "版本信息", desc: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")") {  // 版本号随包显示
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
        .onAppear { bus.refreshAccount() }                   // 进页刷新账号（资料/余额/VIP/配额）
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
        .alert("联系客服", isPresented: $showContact) {       // 联系客服：复制微信号
            Button("复制微信号") {                            // 主操作：写剪贴板
                UIPasteboard.general.string = "doushujun01"  // 客服微信号入剪贴板
                snackbar = "微信号已复制，去微信粘贴添加吧"      // 提示
            }
            Button("取消", role: .cancel) {}                 // 关闭
        } message: {
            Text("微信号：doushujun01\n复制后打开微信 · 搜索添加好友即可")  // 说明文案
        }
        .alert("修改昵称", isPresented: $showNickEdit) {      // 昵称编辑弹窗（iOS16 支持 TextField）
            TextField("2-20 个字符", text: $nickInput)        // 输入框（打开时已预填）
            Button("保存") { saveNickname() }                 // 保存提交（内部防重复）
            Button("取消", role: .cancel) {}                 // 取消关闭
        } message: {
            Text("注册时已自动生成昵称，可随时修改")           // 说明文案
        }
        .onChange(of: pickedItem) { item in handlePick(item) }  // 相册选中 → 压缩上传
    }

    // MARK: - 用户信息渐变横幅（对齐安卓：青→紫渐变底，头像可换、昵称可改）

    private var userBanner: some View {
        HStack(spacing: 14) {                                // 头像+文字横排
            avatarView                                       // 头像（点击换图+相机角标）
            VStack(alignment: .leading, spacing: 3) {        // 右侧文字列
                HStack(spacing: 6) {                         // 昵称+铅笔
                    Text(bus.nickname.isEmpty ? (bus.username.isEmpty ? "抖数君用户" : bus.username) : bus.nickname)  // 昵称空回退用户名
                        .font(.system(size: 18, weight: .bold)).foregroundColor(Color(hex: "04121A"))  // 深色字压亮底
                    Button {                                  // 铅笔：弹昵称编辑
                        nickInput = bus.nickname.isEmpty ? bus.username : bus.nickname  // 预填当前值
                        showNickEdit = true
                    } label: {
                        Image(systemName: "pencil")           // 编辑小图标
                            .font(.system(size: 13)).foregroundColor(Color(hex: "04121A").opacity(0.6))
                    }
                }
                Text(bus.email)                              // 邮箱
                    .font(.system(size: 12)).foregroundColor(Color(hex: "04121A").opacity(0.75))
            }
            Spacer()
        }
        .padding(18)                                         // 横幅内边距
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [T.primary, T.secondary], startPoint: .leading, endPoint: .trailing),  // 青→紫横向渐变（对齐安卓）
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    /// 头像视图：网络图/默认图标 + 上传遮罩 + 右下相机角标（点击拉相册）
    private var avatarView: some View {
        PhotosPicker(selection: $pickedItem, matching: .images) {  // 系统相册选择器（免权限）
            ZStack(alignment: .bottomTrailing) {       // 头像圈+右下角标
                ZStack {                               // 头像主体
                    if let url = bus.avatarUrl, let u = URL(string: url) {  // 有头像：网络图裁圆
                        AsyncImage(url: u) { img in    // 异步加载
                            img.resizable().scaledToFill()          // 填充裁剪
                        } placeholder: {               // 加载中占位
                            ProgressView().tint(Color(hex: "04121A"))
                        }
                    } else {                           // 无头像：默认人形图标
                        Image(systemName: "person.fill")
                            .font(.system(size: 26)).foregroundColor(Color(hex: "04121A"))
                    }
                    if uploadingAvatar {               // 上传中：半透明遮罩+转圈
                        Color.black.opacity(0.5)
                        ProgressView().tint(T.primary)
                    }
                }
                .frame(width: 52, height: 52)          // 头像尺寸（对齐安卓 52dp）
                .clipShape(Circle())                   // 全圆裁剪
                .background(Circle().fill(Color.black.opacity(0.25)))  // 深色底圈（亮渐变上）
                Image(systemName: "camera.fill")       // 右下相机角标：提示可更换
                    .font(.system(size: 8, weight: .bold)).foregroundColor(Color(hex: "04121A"))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(T.primary))  // 亮青底
                    .overlay(Circle().stroke(Color(hex: "04121A"), lineWidth: 1))  // 深描边（亮底上清晰）
            }
        }
        .disabled(uploadingAvatar)                     // 上传中禁选
    }

    // MARK: - 邀请好友横幅（对齐安卓：礼物图标+两行文案+去邀请胶囊）

    private var inviteBanner: some View {
        Button(action: onOpenInvite) {                 // 整条可点进邀请页
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")         // 礼物图标（金色）
                    .font(.system(size: 20)).foregroundColor(T.warn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("邀请好友 · 赚查询次数")        // 主标题
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(T.textMain)
                    Text("新好友注册，双方都能得查询次数")  // 副标题
                        .font(.system(size: 11)).foregroundColor(T.textSub)
                }
                Spacer()
                Text("去邀请")                           // 右侧胶囊按钮
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(T.bg)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(T.primary))  // 青底深字
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(T.card.opacity(0.85)))  // 卡底
        }
    }

    // MARK: - 余额/会员状态卡（对齐安卓：金冠+VIP 三行/未开通两行+续费按钮）

    private var vipCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "rosette")                       // 金色会员徽标
                .font(.system(size: 26)).foregroundColor(T.warn)
            VStack(alignment: .leading, spacing: 3) {          // 左侧信息列
                if bus.isVip {                                 // ---- 已开通会员：三行 ----
                    Text("VIP到期：\(String(bus.vipExpire.prefix(10)))（剩余\(remainDays(bus.vipExpire))天）")  // 完整到期日+剩余天数
                        .font(.system(size: 13, weight: .bold)).foregroundColor(T.warn)
                    Text("作品查询：\(bus.usedToday)/\(bus.dailyLimit)次（剩\(bus.todayRemaining)次）")          // 作品类配额（作品分析）
                        .font(.system(size: 12)).foregroundColor(T.textSub)
                    if bus.hasWeightQuota {                                                                     // 权重类配额（后端拆分支持才显示，老后端兼容）
                        Text("权重查询：\(bus.weightUsedToday)/\(bus.dailyLimit)次（剩\(bus.weightRemainingToday)次）")  // 与作品类各自独立限额
                            .font(.system(size: 12)).foregroundColor(T.textSub)
                    }
                    if !bus.vipPackageName.isEmpty {           // 套餐名胶囊（青色）
                        Text(bus.vipPackageName)
                            .font(.system(size: 10)).foregroundColor(T.primary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(T.primary.opacity(0.12)))
                    }
                } else {                                       // ---- 未开通会员：两行引导 ----
                    Text("未开通会员")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(T.textMain)
                    Text("开通后畅享全部功能不限次")
                        .font(.system(size: 12)).foregroundColor(T.textSub)
                    Text("点数：\(formatBalance(bus.balance)) 次")   // 点数余额（仅未开通显示，对齐安卓）
                        .font(.system(size: 12)).foregroundColor(T.textSub)
                }
            }
            Spacer()
            Button(action: onOpenVip) {                        // 右侧续费/开通按钮
                Text(bus.isVip ? "续费" : "开通")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "241A00"))  // 深琥珀字压金底
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color(hex: "FFD54F"), Color(hex: "FFB300")], startPoint: .leading, endPoint: .trailing),  // 金色渐变
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
        }
        .padding(14)                                           // 卡内边距
        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))  // 玻璃卡底
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(T.stroke, lineWidth: 1))  // 描边
    }

    // MARK: - 交互逻辑

    /// 保存昵称：本地校验 2-20 字符 → POST user/nickname → 回显+落盘
    private func saveNickname() {
        let name = nickInput.trimmingCharacters(in: .whitespaces)  // 去首尾空白（与后端一致）
        guard name.count >= 2 && name.count <= 20, !nickSaving else {  // 长度校验+防重复
            if !nickSaving { snackbar = "昵称长度需为 2-20 个字符" }  // 超长/过短提示
            return
        }
        nickSaving = true                                        // 进入提交态
        Task {                                                   // 后台提交
            defer { nickSaving = false }                         // 退出提交态
            do {
                let d = try await Network.post("user/nickname", body: ["nickname": name])  // 上送昵称
                let cleaned = d["nickname"].str ?? name          // 服务端清洗后的值
                await MainActor.run {                            // 主线程更新
                    bus.nickname = cleaned                       // 即时刷新显示
                    SessionStore.saveNickname(cleaned)           // 持久化
                    snackbar = "昵称已更新"                       // 提示成功
                }
            } catch {                                            // 失败：
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "保存失败，请稍后重试" }  // 展示原因
            }
        }
    }

    /// 相册选中回调：解码 → 压缩（最长边≤512 JPEG 88）→ 上传 → 回显+落盘
    private func handlePick(_ item: PhotosPickerItem?) {
        guard item != nil else { return }                        // 未选中（清空）忽略
        Task {                                                   // 后台处理
            defer { pickedItem = nil }                           // 用完清空（同图可重选）
            guard let raw = try? await item?.loadTransferable(type: Data.self),      // 原图数据
                  let img = UIImage(data: raw),                                     // 解码
                  let jpeg = compressAvatar(img) else {                             // 压缩
                await MainActor.run { snackbar = "图片读取失败，请换一张试试" }         // 读取失败提示
                return
            }
            await MainActor.run { uploadingAvatar = true }       // 主线程置上传中（头像圈遮罩）
            do {
                let d = try await Network.upload("user/avatar", fileData: jpeg, fileName: "avatar.jpg", mimeType: "image/jpeg")  // multipart 上传
                let url = d["avatar"].str ?? ""                  // 完整头像 URL
                await MainActor.run {                            // 主线程收尾
                    if url.isEmpty {                             // 后端没回 URL 视为失败
                        snackbar = "上传失败，请重试"
                    } else {                                     // 成功：立即显示新头像
                        bus.avatarUrl = url                      // 更新总线
                        SessionStore.saveAvatar(url)             // 持久化
                        snackbar = "头像已更新"
                    }
                    uploadingAvatar = false                      // 关遮罩
                }
            } catch {                                            // 失败：
                await MainActor.run {                            // 主线程提示+关遮罩
                    snackbar = (error as? ApiError)?.errorDescription ?? "上传失败，请重试"
                    uploadingAvatar = false
                }
            }
        }
    }

    /// 头像压缩：等比缩到最长边 ≤512px，转 JPEG 质量 0.88（对齐安卓 compressAvatar）
    private func compressAvatar(_ src: UIImage) -> Data? {
        let maxSide: CGFloat = 512                               // 目标最长边
        let scale = min(maxSide / src.size.width, maxSide / src.size.height, 1)  // 只缩不放
        let target = CGSize(width: (src.size.width * scale).rounded(), height: (src.size.height * scale).rounded())  // 目标尺寸
        let drawn = UIGraphicsImageRenderer(size: target).image { _ in src.draw(in: CGRect(origin: .zero, size: target)) }  // 重绘缩放
        return drawn.jpegData(compressionQuality: 0.88)          // JPEG 编码
    }

    /// VIP 到期本地算剩余天数（对齐安卓 remainDays：yyyy-MM-dd 解析，不小于 0）
    private func remainDays(_ expire: String) -> Int {
        guard expire.count >= 10 else { return 0 }               // 至少 yyyy-MM-dd 十位
        let df = DateFormatter()                                 // 日期解析器
        df.dateFormat = "yyyy-MM-dd"                             // 固定格式
        df.timeZone = TimeZone.current                           // 本地时区
        guard let date = df.date(from: String(expire.prefix(10))) else { return 0 }  // 解析失败兜底 0
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0  // 按天差
        return max(days, 0)                                      // 不小于 0
    }

    /// 余额格式化：整数不带小数点，小数保留 2 位（对齐安卓 formatBalance）
    private func formatBalance(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.2f", v)  // 12.0→"12"，12.5→"12.50"
    }

    /// 功能菜单行：彩色图标+标题描述+右箭头
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
