import SwiftUI

// ============================================================================
// VipRechargeView —— 会员充值（web 端 vip/packages + vip/create-order 同款）
// 套餐分组展示 + 微信/支付宝选择 → 创建订单 → 弹出支付页（WebView + 轮询）
// ============================================================================

struct VipRechargeView: View {

    @EnvironmentObject private var store: UserStore   // 全局状态

    // MARK: - 状态

    @State private var packages: [VipPackage] = []    // 套餐列表
    @State private var selectedPackage: VipPackage?   // 当前选中套餐
    @State private var payType = "wxpay"              // 支付方式（wxpay/alipay）
    @State private var isLoading = false              // 套餐加载中
    @State private var isOrdering = false             // 下单中
    @State private var errorMessage = ""              // 错误提示
    @State private var paySheet: PaySheetModel?       // 支付页弹窗模型

    /// 支付弹窗参数（orderNo 轮询用，payUrl WebView 加载）
    struct PaySheetModel: Identifiable {
        let id = UUID()
        let orderNo: String
        let payUrl: String
    }

    var body: some View {
        ZStack {
            CyberBackground()                              // 统一深空背景

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {

                        // ---- 顶部标题区 ----
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VIP 会员中心")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .gradientText(Theme.gold)          // 金色渐变标题
                                // 当前状态：VIP 显示套餐+剩余，普通显示账号
                                Text(store.vipStatus?.isVip == true
                                     ? "当前：\(store.vipStatus?.packageName ?? "VIP") · \(store.vipStatus?.remainText ?? "")"
                                     : "账号：\(store.email.isEmpty ? store.username : store.email)")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Theme.textSub)
                            }
                            Spacer()
                            // 金色皇冠图标 + 光晕
                            Image(systemName: "crown.fill")
                                .font(.system(size: 28))
                                .gradientText(Theme.gold)
                                .shadow(color: Theme.amber.opacity(0.5), radius: 10)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        // ---- 三态内容：加载中 / 错误 / 套餐 ----
                        if isLoading && packages.isEmpty {
                            // 加载态
                            VStack(spacing: 12) {
                                ProgressView().tint(Theme.cyan)
                                Text("正在加载套餐...")
                                    .font(.system(size: 13)).foregroundColor(Theme.textSub)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 70)
                        } else if !errorMessage.isEmpty && packages.isEmpty {
                            // 错误态 + 重试
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 28)).foregroundStyle(Theme.red)
                                Text(errorMessage)
                                    .font(.system(size: 13)).foregroundColor(Theme.red)
                                Button("重新加载") { Task { await loadPackages() } }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 10)
                                    .background(Capsule().fill(Theme.hero))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 60)
                        } else {
                            // 正常态：两组套餐 + 支付方式
                            packageGroup(title: "低请求版", desc: "满足日常查询需求", type: 1)
                            packageGroup(title: "高请求版", desc: "更大每日额度", type: 2)
                            payTypeCard
                        }

                        // 底部说明
                        VStack(spacing: 6) {
                            Text("套餐为虚拟物品，一经订购不予退款")
                            Text("支付完成后 VIP 立即生效")
                        }
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                        Spacer().frame(height: 110)              // 给底部支付栏留空间
                    }
                }

                // ---- 底部固定支付栏（选中套餐才显示）----
                if let pkg = selectedPackage {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¥\(pkg.price)")                // 大号金色价格
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .gradientText(Theme.gold)
                            Text(pkg.name)                        // 套餐名
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSub)
                        }
                        Spacer()
                        Button {
                            Task { await createOrder() }          // 创建订单
                        } label: {
                            HStack(spacing: 8) {
                                if isOrdering {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "lock.open.fill") // 安全支付图标
                                    Text("立即支付")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.gold, height: 48))
                        .frame(width: 150)
                        .disabled(isOrdering)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.bgSoft.ignoresSafeArea(edges: .bottom)) // 深色支付栏
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) // 顶部分隔线
                    }
                }
            }
        }
        // 支付页弹窗（支付成功回调：刷新 VIP+余额）
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
        .task { await loadPackages() }                  // 进入加载套餐
    }

    // MARK: - 套餐分组

    private func packageGroup(title: String, desc: String, type: Int) -> some View {
        VStack(spacing: 12) {
            // 分组标题：图标 + 名 + 描述
            HStack(spacing: 8) {
                Image(systemName: type == 1 ? "bolt.fill" : "flame.fill")   // 低请求=闪电 高请求=火
                    .font(.system(size: 13))
                    .foregroundStyle(type == 1 ? AnyShapeStyle(Theme.cyan) : AnyShapeStyle(Theme.gold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMain)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textDim)
                Spacer()
            }
            // 该分组下的套餐卡
            ForEach(packages.filter { $0.type == type }) { pkg in
                packageCard(pkg)
            }
        }
        .glassCard(radius: 22, padding: 16)
        .padding(.horizontal, 18)
    }

    /// 套餐选择卡：选中态渐变描边+微光
    private func packageCard(_ pkg: VipPackage) -> some View {
        let isSelected = selectedPackage?.id == pkg.id          // 是否选中
        return Button(action: { selectedPackage = pkg }) {      // 点击选中
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pkg.name)                              // 套餐名
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textMain)
                    VStack(alignment: .leading, spacing: 4) {
                        featureText("✓ 有效期 \(pkg.durationText)")          // 时长
                        if pkg.dailyLimit > 0 {
                            featureText("✓ 每天 \(pkg.dailyLimit) 次查询额度")    // 额度
                        }
                        featureText("✓ 无限次取素材")
                    }
                }
                Spacer()
                Text("¥\(pkg.price)")                           // 右侧金色价格
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .gradientText(Theme.gold)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.blue.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.blue.opacity(0.8) : Theme.cardStroke,
                            lineWidth: isSelected ? 1.5 : 1)     // 选中渐变描边
            )
            .shadow(color: isSelected ? Theme.blue.opacity(0.3) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }

    /// 权益行小字
    private func featureText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Theme.textSub)
    }

    // MARK: - 支付方式

    private var payTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "creditcard.fill", title: "支付方式")
            HStack(spacing: 10) {
                payTypeButton(type: "wxpay", icon: "message.fill", label: "微信支付",
                              tint: Theme.green)                 // 微信绿
                payTypeButton(type: "alipay", icon: "a.circle.fill", label: "支付宝",
                              tint: Color(red: 0.22, green: 0.58, blue: 0.98)) // 支付宝蓝
            }
        }
        .glassCard(radius: 22, padding: 16)
        .padding(.horizontal, 18)
    }

    /// 支付方式单选按钮
    private func payTypeButton(type: String, icon: String, label: String, tint: Color) -> some View {
        let isSelected = payType == type                        // 是否选中
        return Button(action: { payType = type }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textMain)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle") // 选中圆
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? tint : Theme.textDim)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint : Theme.cardStroke, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 网络动作

    /// 加载套餐列表
    private func loadPackages() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await API.fetchPackages()            // GET /vip/packages
            packages = list
            if selectedPackage == nil {
                selectedPackage = list.first { $0.type == 1 } ?? list.first  // 默认选低请求版
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 创建支付订单 → 打开支付页
    private func createOrder() async {
        guard let pkg = selectedPackage else { return }
        isOrdering = true
        defer { isOrdering = false }
        do {
            // POST /vip/create-order（web 同款：device_type=desktop 换 pay_url）
            let result = try await API.createOrder(packageId: pkg.id,
                                                   payType: payType,
                                                   userEmail: store.email)
            if result.payUrl.isEmpty {
                errorMessage = "支付链接获取失败，请稍后重试"
                return
            }
            paySheet = PaySheetModel(orderNo: result.orderNo, payUrl: result.payUrl) // 弹支付页
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
