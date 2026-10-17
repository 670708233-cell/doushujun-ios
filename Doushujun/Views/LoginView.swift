import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: UserStore

    @State private var inputId = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.39, blue: 0.92),
                                                          Color(red: 0.35, green: 0.29, blue: 0.92)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 108, height: 108)
                            .shadow(color: Color(red: 0.3, green: 0.4, blue: 0.95).opacity(0.5), radius: 18, y: 8)
                        Text("抖")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("抖数君会员")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                        Text("抖音数据分析 · 会员充值助手")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                    }

                    // 登录卡片
                    VStack(alignment: .leading, spacing: 14) {
                        Text("用户ID登录")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        TextField("请输入小程序的用户ID", text: $inputId)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        Text("获取方式：打开微信小程序「抖数君」→ 我的 → 复制用户ID")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                        }

                        Button(action: { Task { await login() } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("登 录")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.7 : 1)
                    }
                    .padding(20)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 24)

                    // 权益说明
                    VStack(spacing: 10) {
                        benefitRow(icon: "📊", text: "无限制查看数据")
                        benefitRow(icon: "✨", text: "查权重 / 查作品 / 取素材")
                        benefitRow(icon: "🔔", text: "支付后立即生效")
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 15))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.68, green: 0.76, blue: 0.9))
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22).opacity(0.7))
        .cornerRadius(12)
    }

    private func login() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            try await store.login(inputId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
