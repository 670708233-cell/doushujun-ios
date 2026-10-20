import SwiftUI  // UI 框架（含 UIPasteboard 所在 UIKit 域）

/// 邀请好友赚次数（对齐安卓 InviteScreen）：全屏子页——邀请码卡（复制码/链接/二维码）+ 奖励规则 + 统计 + 记录列表
struct InviteView: View {
    var onClose: () -> Void                 // 返回回调
    @State private var info: J? = nil       // 邀请信息（invite_info 响应）
    @State private var records: [J] = []    // 邀请记录列表
    @State private var loading = true       // 首次加载中
    @State private var error = ""           // 错误文案
    @State private var snackbar = ""        // 底部提示（复制反馈）

    var body: some View {
        ZStack {
            TechBackground()                                        // 深空背景
            VStack(spacing: 0) {
                NavBar(title: "邀请好友赚次数", back: onClose)       // 顶栏
                ScrollView(showsIndicators: false) {                // 滚动区
                    VStack(spacing: 14) {
                        if loading {                                // 首次加载：
                            ProgressView().tint(T.primary).padding(.vertical, 80)  // 居中转圈
                        } else if let d = info {                    // 有数据：
                            // 邀请码卡
                            GlassCard {
                                VStack(spacing: 12) {
                                    Text("我的邀请码").font(.system(size: 12)).foregroundColor(T.textSub)  // 小标题
                                    Text(d["invite_code"].str ?? "------")                                 // 大号邀请码
                                        .font(.system(size: 30, weight: .heavy, design: .monospaced)).foregroundColor(T.primary)
                                        .tracking(4)                          // 字距拉开
                                    HStack(spacing: 10) {                     // 双按钮横排
                                        Button { copy(d["invite_code"].str ?? "") } label: {     // 复制邀请码
                                            HStack(spacing: 5) {
                                                Image(systemName: "doc.on.doc")            // 文档图标
                                                Text("复制邀请码").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.bg)             // 深色字
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))  // 渐变底
                                        }
                                        Button { copy(inviteUrl(d)) } label: {                    // 复制邀请链接
                                            HStack(spacing: 5) {
                                                Image(systemName: "link")                  // 链接图标
                                                Text("复制链接").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.primary)        // 青字
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))  // 青淡底
                                        }
                                    }
                                    if let qr = d["qr_code"].str, qr.hasPrefix("data:image") {    // 有二维码（dataURI）：
                                        let b64 = qr.replacingOccurrences(of: "^data:image/\\w+;base64,", with: "", options: .regularExpression)  // 剥 dataURI 头
                                        if let img = Data(base64Encoded: b64).flatMap(UIImage.init) {  // Base64 解码成图
                                            Image(uiImage: img)
                                                .resizable().interpolation(.none).scaledToFit()   // 无插值（保二维码锐利）
                                                .frame(width: 130, height: 130)
                                                .background(Color.white.cornerRadius(10))         // 白底（二维码识读需要）
                                            Text("扫码直达注册页").font(.system(size: 11)).foregroundColor(T.textSub)  // 说明
                                        }
                                    }
                                }
                            }

                            // 奖励规则
                            let rules = d["rules"].arr.compactMap(\.str)   // 规则文本数组（滤空）
                            if !rules.isEmpty {                            // 有规则才显示区块
                                SectionTitle(text: "奖励规则")
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(rules, id: \.self) { r in  // 逐条渲染
                                            HStack(alignment: .top, spacing: 6) {  // 圆点+文本
                                                Text("·").foregroundColor(T.primary)  // 品牌色圆点
                                                Text(r).font(.system(size: 13)).foregroundColor(T.textSub)  // 规则文本
                                            }
                                        }
                                    }
                                }
                            }

                            // 我的邀请统计
                            SectionTitle(text: "我的邀请")
                            GlassCard {
                                HStack {                       // 两指标等分
                                    MetricCell(value: String(d["total_invited"].int ?? 0), label: "已邀请好友", color: T.primary)        // 邀请人数
                                    MetricCell(value: String(d["total_reward_points"].int ?? 0), label: "累计奖励点数", color: T.warn)   // 奖励点数
                                }
                            }

                            // 记录列表
                            SectionTitle(text: "邀请记录")
                            if records.isEmpty {               // 无记录：
                                GlassCard { EmptyState(icon: "person.2", text: "暂无邀请记录，快去邀请好友吧") }  // 空态
                            } else {                           // 有记录：
                                ForEach(Array(records.enumerated()), id: \.offset) { _, r in  // 逐条卡片
                                    GlassCard(padding: 12) {
                                        HStack {               // 左信息右奖励
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(r["email_masked"].str ?? r["username"].str ?? "新好友")   // 脱敏邮箱/用户名
                                                    .font(.system(size: 14)).foregroundColor(T.textMain)
                                                Text((r["created_at"].str ?? "").replacingOccurrences(of: "T", with: " "))  // 时间（ISO T 转空格）
                                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                                            }
                                            Spacer()
                                            Text("+\(r["reward_points"].int ?? 0) 点")   // 奖励点数
                                                .font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        } else {                           // 加载失败/无信息：
                            GlassCard { EmptyState(icon: "person.2", text: error.isEmpty ? "加载中…" : error) }  // 空态或错误
                        }
                    }
                    .padding(.horizontal, 16)              // 左右留白
                    .padding(.bottom, 30)                  // 底部留白
                }
            }
        }
        .snackbar($snackbar)                               // 复制提示
        .onAppear { load() }                               // 进页加载
    }

    /// 拼邀请链接：后端有 invite_url 用之，否则按注册页+邀请码拼
    private func inviteUrl(_ d: J) -> String {
        let u = d["invite_url"].str ?? ""                  // 后端直发链接
        if !u.isEmpty { return u }                         // 非空直用
        return "https://doushujun.me/register?invite=\(d["invite_code"].str ?? "")"  // 兜底拼接
    }

    /// 写剪贴板并提示
    private func copy(_ s: String) {
        UIPasteboard.general.string = s                    // 写系统剪贴板
        snackbar = "已复制"                                 // Snackbar 反馈
    }

    /// 加载邀请信息与记录（双接口串行，失败静默仅报信息失败）
    private func load() {
        Task {                                             // 后台任务
            defer { loading = false }                      // 完成即退出加载态
            info = try? await Network.get("user/invite_info")                   // 邀请信息（失败 nil）
            if let d = try? await Network.get("user/invite_records") {          // 邀请记录：
                records = d["list"].arr.isEmpty ? d.arr : d["list"].arr         // list 节点优先，空则回退根数组
            }
            if info == nil { error = "加载失败，请稍后重试" }                    // 信息失败才报错
        }
    }
}
