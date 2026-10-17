import SwiftUI

/// 会员充值（web 端 vip/packages + vip/create-order 同款）
struct VipRechargeView: View {
    @EnvironmentObject private var store: UserStore

    @State private var packages: [VipPackage] = []
    @State private var selectedPackage: VipPackage?
    @State private var payType = "wxpay"
    @State private var isLoading = false
    @State private var isOrdering = false
    @State private var errorMessage = ""
    @State private var paySheet: PaySheetModel?

    struct PaySheetModel: Identifiable {
        let id = UUID()
        let orderNo: String
        let payUrl: String
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard

                        if isLoading && packages.isEmpty {
                            ProgressView("正在加载套餐...")
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                        } else if !errorMessage.isEmpty && packages.isEmpty {
                            VStack(spacing: 12) {
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                Button("重新加载") { Task { await loadPackages() } }
                                    .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                            }
                            .padding(.vertical, 60)
                        } else {
                            packageGroup(title: "低请求版", desc: "满足日常查询需求", type: 1)
                            packageGroup(title: "高请求版", desc: "更大每日额度", type: 2)

                            payTypeCard
                        }

                        VStack(spacing: 8) {
                            Text("说明：套餐为虚拟物品，一经订购不予退款。")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))
                            Text("支付完成后 VIP 立即生效")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)

                        Spacer().frame(height: 110)
                    }
                }

                // 固定支付栏
                if let pkg = selectedPackage {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¥\(pkg.price)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.62, blue: 0.24))
                            Text(pkg.name)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                        }
                        Spacer()
                        Button(action: { Task { await createOrder() } }) {
                            HStack {
                                if isOrdering {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("立即支付")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(width: 150, height: 46)
                            .background(LinearGradient(colors: [Color(red: 0.95, green: 0.62, blue: 0.24),
                                                                Color(red: 0.93, green: 0.42, blue: 0.24)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isOrdering)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                }
            }
        }
        .sheet(item: $paySheet) { model in
            PayView(orderNo: model.orderNo, payUrl: model.payUrl) { paid in
                paySheet = nil
                if paid {
                    Task {
                        async let _ = store.refreshVip(showLoading: true)
                        async let _ = store.refreshBalance()
                    }
                }
            }
        }
        .task { await loadPackages() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("开通 VIP 会员")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            let isVip = store.vipStatus?.isVip ?? false
            Text(isVip
                 ? "当前状态：\(store.vipStatus?.packageName ?? "VIP") · \(store.vipStatus?.remainText ?? "")"
                 : "账号：\(store.email.isEmpty ? store.username : store.email)")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func packageGroup(title: String, desc: String, type: Int) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
            }
            .frame(maxWidth: .infinity)

            ForEach(packages.filter { $0.type == type }) { pkg in
                packageCard(pkg)
            }
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
    }

    private func packageCard(_ pkg: VipPackage) -> some View {
        let isSelected = selectedPackage?.id == pkg.id
        return Button(action: { selectedPackage = pkg }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pkg.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        featureText("✓ \(pkg.durationText)")
                        if pkg.dailyLimit > 0 {
                            featureText("✓ 每天\(pkg.dailyLimit)次查询")
                        }
                        featureText("✓ 无限次取素材")
                    }
                }
                Spacer()
                Text("¥\(pkg.price)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.62, blue: 0.24))
            }
            .padding(16)
            .background(isSelected ? Color(red: 0.13, green: 0.2, blue: 0.38) : Color(red: 0.11, green: 0.16, blue: 0.28))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(red: 0.4, green: 0.55, blue: 1.0) : Color.white.opacity(0.06), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var payTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("支付方式")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            HStack(spacing: 10) {
                payTypeButton(type: "wxpay", icon: "message.fill", label: "微信支付",
                              tint: Color(red: 0.3, green: 0.75, blue: 0.42))
                payTypeButton(type: "alipay", icon: "a.circle.fill", label: "支付宝",
                              tint: Color(red: 0.2, green: 0.55, blue: 0.95))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
    }

    private func payTypeButton(type: String, icon: String, label: String, tint: Color) -> some View {
        let isSelected = payType == type
        return Button(action: { payType = type }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? tint : Color(red: 0.45, green: 0.5, blue: 0.62))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? tint.opacity(0.12) : Color(red: 0.11, green: 0.16, blue: 0.28))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? tint : Color.white.opacity(0.06), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func featureText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Color(red: 0.62, green: 0.72, blue: 0.88))
    }

    private func loadPackages() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await API.fetchPackages()
            packages = list
            if selectedPackage == nil {
                selectedPackage = list.first { $0.type == 1 } ?? list.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createOrder() async {
        guard let pkg = selectedPackage else { return }
        isOrdering = true
        defer { isOrdering = false }
        do {
            let result = try await API.createOrder(packageId: pkg.id,
                                                   payType: payType,
                                                   userEmail: store.email)
            if result.payUrl.isEmpty {
                errorMessage = "支付链接获取失败，请稍后重试"
                return
            }
            paySheet = PaySheetModel(orderNo: result.orderNo, payUrl: result.payUrl)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
