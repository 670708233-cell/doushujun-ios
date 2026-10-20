import SwiftUI  // UI 框架

/// 意见反馈（对齐安卓 FeedbackScreen）：全屏子页——类型胶囊单选 + 内容多行输入 + 联系方式选填
struct FeedbackView: View {
    var onClose: () -> Void                       // 返回回调

    @State private var type = "功能异常"           // 当前选中类型（默认第一项）
    @State private var content = ""               // 反馈内容
    @State private var contact = ""               // 联系方式（选填）
    @State private var loading = false            // 提交中
    @State private var error = ""                 // 错误/结果提示（同时挂 snackbar）
    private let types = ["功能异常", "体验建议", "其他"]  // 类型候选

    var body: some View {
        ZStack {
            TechBackground()                     // 深空背景
            VStack(spacing: 0) {
                NavBar(title: "意见反馈", back: onClose)   // 顶栏
                ScrollView(showsIndicators: false) {       // 内容滚动区
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard {                        // 表单卡片
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(text: "反馈类型")          // 类型区块
                                HStack(spacing: 8) {                    // 胶囊横排
                                    ForEach(types, id: \.self) { t in   // 遍历候选
                                        Button {
                                            type = t                 // 点选切换
                                        } label: {
                                            Text(t)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(type == t ? T.bg : T.textSub)                 // 选中深色字
                                                .padding(.horizontal, 14).padding(.vertical, 8)                // 胶囊内边距
                                                .background(Capsule().fill(type == t ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.06))))  // 选中渐变底
                                                .overlay(Capsule().stroke(type == t ? .clear : T.stroke, lineWidth: 1))  // 未选中描边
                                        }
                                    }
                                }
                                SectionTitle(text: "反馈内容")          // 内容区块
                                TextField("请详细描述你遇到的问题或建议（至少10个字）", text: $content)  // 多行输入（轴对齐顶部）
                                    .font(.system(size: 14)).foregroundColor(T.textMain)
                                    .padding(10)
                                    .frame(height: 120, alignment: .topLeading)               // 高 120 顶对齐
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))  // 淡白底
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))      // 描边
                                SectionTitle(text: "联系方式（选填）")    // 联系方式区块
                                DSJField(placeholder: "邮箱/微信，方便我们回访", text: $contact)  // 单行输入
                                ErrorText(text: error)                  // 错误红字
                                PrimaryButton(title: "提交反馈", loading: loading) { submit() }  // 提交按钮
                            }
                        }
                        Text("我们会认真对待每一条反馈，感谢你的支持！")   // 底部致谢
                            .font(.system(size: 12)).foregroundColor(T.textSub)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)          // 左右留白
                    .padding(.bottom, 30)              // 底部留白
                }
            }
        }
        .snackbar($error)                              // 结果同时以 snackbar 呈现
    }

    /// 提交：本地校验 ≥10 字 → POST user/feedback → 清空并提示
    private func submit() {
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)  // 清洗内容
        guard c.count >= 10 else { error = "反馈内容至少 10 个字"; return }  // 本地长度校验
        loading = true                              // 进入提交态
        error = ""                                  // 清旧提示
        Task {                                      // 后台提交
            defer { loading = false }               // 无论成败退出提交态
            do {
                _ = try await Network.post("user/feedback", body: [   // 上送三字段
                    "type": type,                                       // 类型
                    "content": c,                                       // 内容
                    "contact": contact.trimmingCharacters(in: .whitespaces),  // 联系方式（去空白）
                ])
                await MainActor.run {                   // 主线程收尾
                    content = ""                        // 清内容
                    contact = ""                        // 清联系方式
                    error = "感谢反馈！我们会尽快处理"    // 成功提示
                }
            } catch {                                   // 失败：
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "提交失败" }  // 展示原因
            }
        }
    }
}
