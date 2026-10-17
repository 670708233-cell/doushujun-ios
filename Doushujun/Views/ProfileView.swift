import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: UserStore

    @State private var toast: String?
    @State private var showLogoutConfirm = false

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
                            Text("抖")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("用户ID：\(store.userId)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        let vip = store.vipStatus
                        Text(vip?.isVip == true ? "VIP会员 · \(vip?.packageName ?? "")" : "普通用户")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(vip?.isVip == true ? Color(red: 1.0, green: 0.82, blue: 0.35) : Color(red: 0.6, green: 0.66, blue: 0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((vip?.isVip == true ? Color(red: 1.0, green: 0.82, blue: 0.35) : Color.white).opacity(0.1))
                            .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // 功能列表
                    VStack(spacing: 0) {
                        actionRow(icon: "doc.on.doc", title: "复制用户ID") {
                            UIPasteboard.general.string = store.userId
                            showToast("用户ID已复制")
                        }
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                        actionRow(icon: "arrow.clockwise", title: "刷新会员信息") {
                            Task {
                                let ok = await store.refreshVip(showLoading: true)
                                showToast(ok ? "会员信息已刷新" : "刷新失败，请重试")
                            }
                        }
                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                        actionRow(icon: "questionmark.circle", title: "开通步骤") {
                            showLogoutConfirm = false
                            showToast("购买会员页选套餐支付即可开通")
                        }
                    }
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    // 开通步骤说明
                    VStack(alignment: .leading, spacing: 10) {
                        Text("开通步骤")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        stepRow("①", "在「购买会员」页选择套餐")
                        stepRow("②", "点击「立即支付」，在新页面完成付款")
                        stepRow("③", "支付完成后回到「会员中心」刷新查看")
                        Text("一次开通，长期使用")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

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
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { store.logout() }
            Button("取消", role: .cancel) {}
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

    private func stepRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.72, green: 0.79, blue: 0.92))
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
