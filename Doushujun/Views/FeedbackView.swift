import SwiftUI

/// 意见反馈（对齐安卓 FeedbackScreen）
struct FeedbackView: View {
    var onClose: () -> Void

    @State private var type = "功能异常"
    @State private var content = ""
    @State private var contact = ""
    @State private var loading = false
    @State private var error = ""
    private let types = ["功能异常", "体验建议", "其他"]

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "意见反馈", back: onClose)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(text: "反馈类型")
                                HStack(spacing: 8) {
                                    ForEach(types, id: \.self) { t in
                                        Button {
                                            type = t
                                        } label: {
                                            Text(t)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(type == t ? T.bg : T.textSub)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(Capsule().fill(type == t ? AnyShapeStyle(T.grad) : AnyShapeStyle(Color.white.opacity(0.06))))
                                                .overlay(Capsule().stroke(type == t ? .clear : T.stroke, lineWidth: 1))
                                        }
                                    }
                                }
                                SectionTitle(text: "反馈内容")
                                TextField("请详细描述你遇到的问题或建议（至少10个字）", text: $content)
                                    .font(.system(size: 14)).foregroundColor(T.textMain)
                                    .padding(10)
                                    .frame(height: 120, alignment: .topLeading)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                                SectionTitle(text: "联系方式（选填）")
                                DSJField(placeholder: "邮箱/微信，方便我们回访", text: $contact)
                                ErrorText(text: error)
                                PrimaryButton(title: "提交反馈", loading: loading) { submit() }
                            }
                        }
                        Text("我们会认真对待每一条反馈，感谢你的支持！")
                            .font(.system(size: 12)).foregroundColor(T.textSub)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .snackbar($error)
    }

    private func submit() {
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard c.count >= 10 else { error = "反馈内容至少 10 个字"; return }
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                _ = try await Network.post("user/feedback", body: [
                    "type": type,
                    "content": c,
                    "contact": contact.trimmingCharacters(in: .whitespaces),
                ])
                await MainActor.run {
                    content = ""
                    contact = ""
                    error = "感谢反馈！我们会尽快处理"
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "提交失败" }
            }
        }
    }
}
