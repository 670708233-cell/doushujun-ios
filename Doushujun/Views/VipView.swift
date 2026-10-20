import SwiftUI
import SafariServices

/// VIP 会员与点数充值（对齐安卓 VipScreen）
struct VipView: View {
    var onClose: () -> Void
    @ObservedObject private var bus = SessionBus.shared

    @State private var tab = 0   // 0=会员套餐 1=点数充值
    @State private var packages: [J] = []
    @State private var selectedPkg: String? = nil
    @State private var pointTiers: [(amount: Double, points: Double)] = []
    @State private var selectedTier: Double? = nil
    @State private var customAmount = ""
    @State private var allowPointRecharge = false
    @State private var loading = false
    @State private var error = ""
    @State private var paying = false
    @State private var payUrl: String? = nil
    @State private var payOrderId: String? = nil
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "会员与充值", back: onClose)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 余额卡
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("当前余额").font(.system(size: 11)).foregroundColor(T.textSub)
                                    Text(String(format: "%.2f", bus.balance))
                                        .font(.system(size: 24, weight: .heavy)).foregroundColor(T.primary)
                                }
                                Spacer()
                                if bus.vipLevel != "免费用户" {
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(bus.vipLevel).font(.system(size: 13, weight: .bold)).foregroundColor(T.warn)
                                        Text("到期 \(String(bus.vipExpire.prefix(10)))").font(.system(size: 11)).foregroundColor(T.textSub)
                                    }
                                } else {
                                    Text("免费用户").font(.system(size: 13)).foregroundColor(T.textSub)
                                }
                            }
                        }

                        // Tab
                        HStack(spacing: 0) {
                            segBtn("会员套餐", 0)
                            if allowPointRecharge { segBtn("点数充值", 1) }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                        .padding(.horizontal, 16)

                        if loading && packages.isEmpty {
                            ProgressView().tint(T.primary).padding(.vertical, 60)
                        } else if tab == 0 {
                            pkgList
                        } else {
                            pointList
                        }
                        ErrorText(text: error).padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .snackbar($error)
        .onAppear { load() }
        .sheet(isPresented: Binding(get: { payUrl != nil }, set: { if !$0 { payUrl = nil } })) {
            SafariPayView(url: payUrl ?? "")
        }
        .alert("支付成功", isPresented: $showSuccess) {
            Button("好的") { load(); bus.refreshAccount() }
        } message: {
            Text("充值已到账，余额已刷新")
        }
    }

    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            error = ""
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - 会员套餐列表

    @ViewBuilder
    private var pkgList: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(packages.enumerated()), id: \.offset) { i, p in
                let id = p["id"].str ?? String(i)
                let sel = selectedPkg == id
                Button {
                    selectedPkg = id
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(p["name"].str ?? "套餐").font(.system(size: 15, weight: .bold)).foregroundColor(T.textMain)
                            Spacer()
                            if p["badge"].exists {
                                Text(p["badge"].str ?? "推荐")
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(T.bg)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Capsule().fill(T.warn))
                            }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("¥").font(.system(size: 13, weight: .bold)).foregroundColor(T.primary)
                            Text(String(format: "%.2f", p["price"].dbl ?? 0))
                                .font(.system(size: 24, weight: .heavy)).foregroundColor(T.primary)
                            if let op = p["original_price"].dbl, op > (p["price"].dbl ?? 0) {
                                Text(String(format: "¥%.0f", op))
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                                    .strikethrough()
                            }
                        }
                        if let dd = p["duration_days"].int { Text("时长 \(dd) 天").font(.system(size: 11)).foregroundColor(T.textSub) }
                        if let dl = p["daily_limit"].int { Text("每日 \(dl == 0 ? "不限" : String(dl)) 次查询").font(.system(size: 11)).foregroundColor(T.textSub) }
                        ForEach(p["features"].arr.compactMap(\.str).prefix(4), id: \.self) { f in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundColor(.green)
                                Text(f).font(.system(size: 10)).foregroundColor(T.textSub).lineLimit(1)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(sel ? T.primary.opacity(0.10) : T.card.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(sel ? T.primary : T.stroke, lineWidth: sel ? 1.5 : 1))
                }
            }
        }
        .padding(.horizontal, 16)

        // 支付按钮
        PrimaryButton(title: "立即开通", loading: paying, enabled: selectedPkg != nil) {
            if let pid = selectedPkg { createVipOrder(pkgId: pid) }
        }
        .padding(.horizontal, 16)

        Text("支持支付宝 / 微信扫码支付，支付完成后余额与会员自动到账")
            .font(.system(size: 11)).foregroundColor(T.textSub)
    }

    // MARK: - 点数充值

    @ViewBuilder
    private var pointList: some View {
        SectionTitle(text: "选择充值金额").padding(.horizontal, 16)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(pointTiers, id: \.amount) { t in
                let sel = selectedTier == t.amount && customAmount.isEmpty
                Button {
                    selectedTier = t.amount
                    customAmount = ""
                } label: {
                    VStack(spacing: 4) {
                        Text("¥\(t.amount == t.amount.rounded() ? String(Int(t.amount)) : String(format: "%.0f", t.amount))")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(sel ? T.bg : T.textMain)
                        Text("\(t.points == t.points.rounded() ? String(Int(t.points)) : String(format: "%.0f", t.points)) 点")
                            .font(.system(size: 11)).foregroundColor(sel ? T.bg.opacity(0.8) : T.primary)
                    }
                    .frame(maxWidth: .infinity).frame(height: 66)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(sel ? AnyShapeStyle(T.grad) : AnyShapeStyle(T.card.opacity(0.9))))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? .clear : T.stroke, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)

        HStack(spacing: 10) {
            DSJField(placeholder: "自定义金额(元)", text: $customAmount, keyboard: .decimalPad)
        }
        .padding(.horizontal, 16)
        .onChange(of: customAmount) { v in
            if !v.isEmpty { selectedTier = nil }
        }

        PrimaryButton(title: "立即充值", loading: paying) {
            createPointOrder()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - 数据

    private func load() {
        loading = true
        Task {
            defer { loading = false }
            // 套餐
            if let d = try? await Network.get("vip/packages") {
                await MainActor.run {
                    packages = d.arr.isEmpty ? [d] : d.arr
                    if selectedPkg == nil { selectedPkg = packages.first.flatMap { $0["id"].str } }
                }
            }
            // 站点配置（点数充值开关）
            if let s = try? await Network.get("admin/getsite") {
                await MainActor.run { allowPointRecharge = s["allow_point_recharge"].bool }
            }
            // 点数档位 Map {金额: 点数}
            if let d = try? await Network.get("recharge/packages") {
                var tiers: [(amount: Double, points: Double)] = []
                for (k, v) in d.dict {
                    if let amount = Double(k), let pts = v.dbl { tiers.append((amount, pts)) }
                }
                tiers.sort { $0.0 < $1.0 }
                await MainActor.run {
                    pointTiers = tiers
                    selectedTier = tiers.first?.amount
                }
            }
        }
    }

    /// 下单 + 打开收银台 + 轮询到账（会员）
    private func createVipOrder(pkgId: String) {
        paying = true
        error = ""
        Task {
            defer { paying = false }
            do {
                let d = try await Network.post("vip/create-order", body: [
                    "package_id": pkgId,
                    "pay_method": "alipay",
                    "device_type": "pc",
                ])
                let url = d["pay_url"].str ?? d["recharge_url"].str ?? ""
                let oid = d["order_id"].str ?? d["order_no"].str ?? ""
                guard !url.isEmpty else { throw ApiError.business("获取支付链接失败") }
                await MainActor.run {
                    payUrl = url
                    payOrderId = oid
                }
                pollPaid(orderId: oid)
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "下单失败" }
            }
        }
    }

    /// 点数充值下单
    private func createPointOrder() {
        var amount = selectedTier ?? 0
        if let ca = Double(customAmount), ca > 0 {
            amount = ca
            // 自定义金额按套餐比例找点数；找不到按 1元=10点 兜底
            amount = ca
        }
        guard amount > 0 else { error = "请选择或输入充值金额"; return }
        let points = pointTiers.first { $0.amount == amount }?.points ?? amount * 10
        paying = true
        error = ""
        Task {
            defer { paying = false }
            do {
                let d = try await Network.post("recharge/create", body: [
                    "amount": amount,
                    "points": points,
                    "type": "point",
                    "user_email": SessionStore.email,
                    "device_type": "pc",
                ])
                let url = d["pay_url"].str ?? d["recharge_url"].str ?? ""
                let oid = d["order_id"].str ?? d["order_no"].str ?? ""
                guard !url.isEmpty else { throw ApiError.business("获取支付链接失败") }
                await MainActor.run {
                    payUrl = url
                    payOrderId = oid
                }
                pollPaid(orderId: oid)
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "下单失败" }
            }
        }
    }

    /// 每 2.5s 轮询 recharge/query（最长 10 分钟）
    private func pollPaid(orderId: String) {
        guard !orderId.isEmpty else { return }
        Task {
            for _ in 0..<240 {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if payUrl == nil { return }   // 用户已关闭
                if let d = try? await Network.get("recharge/query", query: ["order_id": orderId]) {
                    let paid = d["status"].str == "paid" || d["paid"].bool || d["status"].str == "success"
                    if paid {
                        await MainActor.run {
                            payUrl = nil
                            showSuccess = true
                        }
                        return
                    }
                }
            }
        }
    }
}

/// Safari 收银台（页面关闭后轮询继续）
struct SafariPayView: UIViewControllerRepresentable {
    let url: String

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: URL(string: url) ?? URL(fileURLWithPath: "/dev/null"))
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
