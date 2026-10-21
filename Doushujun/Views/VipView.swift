import SwiftUI
import SafariServices

// ============================================================================
// VipView.swift — VIP 会员与点数充值页
// 职责：余额/VIP 状态卡 + 会员套餐列表 + 点数档位/自定义充值
//       + Safari 收银台 + 2.5s 轮询到账（对齐安卓 VipScreen）
// ============================================================================

/// VIP 会员与点数充值（对齐安卓 VipScreen）
struct VipView: View {
    var onClose: () -> Void                          // 返回回调（关闭全屏弹层）
    @ObservedObject private var bus = SessionBus.shared

    @State private var tab = 0   // 0=会员套餐 1=点数充值
    @State private var packages: [J] = []            // 会员套餐列表
    @State private var selectedPkg: String? = nil    // 选中的套餐 id
    @State private var pointTiers: [(amount: Double, points: Double)] = []  // 点数档位（金额→点数）
    @State private var selectedTier: Double? = nil   // 选中的档位金额
    @State private var customAmount = ""             // 自定义充值金额输入
    @State private var allowPointRecharge = false    // 站点是否开放点数充值（决定 Tab 显隐）
    @State private var loading = false               // 首屏加载中
    @State private var error = ""                    // 错误文案（兼 snackbar）
    @State private var paying = false                // 下单请求中
    @State private var payUrl: String? = nil         // 收银台链接（非 nil 弹 Safari）
    @State private var payOrderId: String? = nil     // 当前订单号（轮询用）
    @State private var showSuccess = false           // 到账成功弹窗

    var body: some View {
        ZStack {
            TechBackground()                         // 科技感背景
            VStack(spacing: 0) {
                NavBar(title: "会员与充值", back: onClose)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 余额卡
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("当前余额").font(.system(size: 11)).foregroundColor(T.textSub)
                                    Text(String(format: "%.2f", bus.balance))  // 余额两位小数
                                        .font(.system(size: 24, weight: .heavy)).foregroundColor(T.primary)
                                }
                                Spacer()
                                if bus.vipLevel != "免费用户" {   // 有会员：等级+到期日
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(bus.vipLevel).font(.system(size: 13, weight: .bold)).foregroundColor(T.warn)
                                        Text("到期 \(String(bus.vipExpire.prefix(10)))").font(.system(size: 11)).foregroundColor(T.textSub)  // 只取日期段
                                    }
                                } else {
                                    Text("免费用户").font(.system(size: 13)).foregroundColor(T.textSub)
                                }
                            }
                        }

                        // Tab
                        HStack(spacing: 0) {
                            segBtn("会员套餐", 0)
                            if allowPointRecharge { segBtn("点数充值", 1) }  // 站点开关控制
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                        .padding(.horizontal, 16)

                        if loading && packages.isEmpty { // 首屏加载态
                            ProgressView().tint(T.primary).padding(.vertical, 60)
                        } else if tab == 0 {
                            pkgList                      // 会员套餐网格
                        } else {
                            pointList                    // 点数充值面板
                        }
                        ErrorText(text: error).padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .snackbar($error)
        .onAppear { load() }                             // 进页拉套餐/配置/档位
        .sheet(isPresented: Binding(get: { payUrl != nil }, set: { if !$0 { payUrl = nil } })) {
            SafariPayView(url: payUrl ?? "")             // Safari 收银台弹窗
        }
        .alert("支付成功", isPresented: $showSuccess) {
            Button("好的") { load(); bus.refreshAccount() }  // 到账后刷新套餐与全局余额
        } message: {
            Text("充值已到账，余额已刷新")
        }
    }

    /// 会员/点数分段按钮（选中渐变胶囊）
    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            error = ""                                   // 切换清错误
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - 会员套餐列表

    /// 两列套餐网格：名称/角标/价格/划线原价/时长/日限/权益，选中高亮描边
    @ViewBuilder
    private var pkgList: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(packages.enumerated()), id: \.offset) { i, p in
                let id = p["id"].str ?? String(i)
                let sel = selectedPkg == id
                Button {                                 // 点卡选中
                    selectedPkg = id
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(p["name"].str ?? "套餐").font(.system(size: 15, weight: .bold)).foregroundColor(T.textMain)
                            Spacer()
                            if p["badge"].exists {       // 角标（推荐等）
                                Text(p["badge"].str ?? "推荐")
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(T.bg)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Capsule().fill(T.warn))
                            }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("¥").font(.system(size: 13, weight: .bold)).foregroundColor(T.primary)
                            Text(String(format: "%.2f", p["price"].dbl ?? 0))  // 现价大字
                                .font(.system(size: 24, weight: .heavy)).foregroundColor(T.primary)
                            if let op = p["original_price"].dbl, op > (p["price"].dbl ?? 0) {  // 原价更高才显示
                                Text(String(format: "¥%.0f", op))
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                                    .strikethrough()     // 划线原价
                            }
                        }
                        if let dd = p["duration_days"].int { Text("时长 \(dd) 天").font(.system(size: 11)).foregroundColor(T.textSub) }
                        if let dl = p["daily_limit"].int { Text("每日 \(dl == 0 ? "不限" : String(dl)) 次查询").font(.system(size: 11)).foregroundColor(T.textSub) }  // 0=不限
                        ForEach(p["features"].arr.compactMap(\.str).prefix(4), id: \.self) { f in  // 权益最多 4 条
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundColor(.green)
                                Text(f).font(.system(size: 10)).foregroundColor(T.textSub).lineLimit(1)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(sel ? T.primary.opacity(0.10) : T.card.opacity(0.9)))           // 选中淡主色底
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(sel ? T.primary : T.stroke, lineWidth: sel ? 1.5 : 1))        // 选中加粗描边
                }
            }
        }
        .padding(.horizontal, 16)

        // 支付按钮
        PrimaryButton(title: "立即开通", loading: paying, enabled: selectedPkg != nil) {  // 未选套餐禁用
            if let pid = selectedPkg { createVipOrder(pkgId: pid) }
        }
        .padding(.horizontal, 16)

        Text("支持支付宝 / 微信扫码支付，支付完成后余额与会员自动到账")
            .font(.system(size: 11)).foregroundColor(T.textSub)
    }

    // MARK: - 点数充值

    /// 点数充值面板：三列档位网格 + 自定义金额 + 下单按钮
    @ViewBuilder
    private var pointList: some View {
        SectionTitle(text: "选择充值金额").padding(.horizontal, 16)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(pointTiers, id: \.amount) { t in
                let sel = selectedTier == t.amount && customAmount.isEmpty   // 输入自定义金额时档位取消选中
                Button {
                    selectedTier = t.amount
                    customAmount = ""                        // 选档位清自定义
                } label: {
                    VStack(spacing: 4) {
                        Text("¥\(t.amount == t.amount.rounded() ? String(Int(t.amount)) : String(format: "%.0f", t.amount))")  // 整数不带小数
                            .font(.system(size: 16, weight: .bold)).foregroundColor(sel ? T.bg : T.textMain)
                        Text("\(t.points == t.points.rounded() ? String(Int(t.points)) : String(format: "%.0f", t.points)) 点")  // 对应点数
                            .font(.system(size: 11)).foregroundColor(sel ? T.bg.opacity(0.8) : T.primary)
                    }
                    .frame(maxWidth: .infinity).frame(height: 66)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(sel ? AnyShapeStyle(T.grad) : AnyShapeStyle(T.card.opacity(0.9))))  // 选中渐变底
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? .clear : T.stroke, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)

        HStack(spacing: 10) {
            DSJField(placeholder: "自定义金额(元)", text: $customAmount, keyboard: .decimalPad)  // 数字键盘
        }
        .padding(.horizontal, 16)
        .onChange(of: customAmount) { v in
            if !v.isEmpty { selectedTier = nil }             // 输入自定义即取消档位
        }

        PrimaryButton(title: "立即充值", loading: paying) {
            createPointOrder()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - 数据

    /// 并发拉三类数据：会员套餐 / 站点配置（点数开关）/ 点数档位 Map
    private func load() {
        loading = true
        Task {
            defer { loading = false }
            // 套餐
            if let d = try? await Network.get("vip/packages") {
                await MainActor.run {
                    packages = d.arr.isEmpty ? [d] : d.arr   // 数组或单对象双兼容
                    if selectedPkg == nil { selectedPkg = packages.first.flatMap { $0["id"].str } }  // 默认选第一个
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
                    if let amount = Double(k), let pts = v.dbl { tiers.append((amount, pts)) }  // key=金额 value=点数
                }
                tiers.sort { $0.0 < $1.0 }                   // 按金额升序
                await MainActor.run {
                    pointTiers = tiers
                    selectedTier = tiers.first?.amount       // 默认选最低档
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
                    "user_email": SessionStore.email,        // 后端必校验（缺=「缺少必要参数」实证）
                    "type": "alipay",                        // 支付渠道（参数名对齐安卓）
                    "device_type": "pc",
                ])
                let url = d["pay_url"].str ?? d["recharge_url"].str ?? ""   // 收银台链接双字段兼容
                let oid = d["order_id"].str ?? d["order_no"].str ?? ""      // 订单号双字段兼容
                guard !url.isEmpty else { throw ApiError.business("获取支付链接失败") }
                await MainActor.run {
                    payUrl = url                             // 弹 Safari
                    payOrderId = oid
                }
                pollPaid(orderId: oid)                       // 开始轮询
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "下单失败" }
            }
        }
    }

    /// 点数充值下单
    private func createPointOrder() {
        var amount = selectedTier ?? 0
        if let ca = Double(customAmount), ca > 0 {           // 自定义金额优先
            amount = ca
        }
        guard amount > 0 else { error = "请选择或输入充值金额"; return }
        // 档位点数优先（recharge/packages 后端下发）；自定义金额按后端分段公式
        // （对齐 Recharge::getPointsForAmount：≤75 ×10；76-200 ×15；201-500 ×20；501+ ×30，
        //  不匹配会被后端以「点数计算不匹配」拒单）
        let points = pointTiers.first { $0.amount == amount }?.points ?? {
            switch amount {
            case ..<76: return amount * 10
            case ..<201: return amount * 15
            case ..<501: return amount * 20
            default: return amount * 30
            }
        }()
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
        guard !orderId.isEmpty else { return }               // 无单号不轮询
        Task {
            for _ in 0..<240 {                               // 240 次 × 2.5s = 10 分钟
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if payUrl == nil { return }   // 用户已关闭
                if let d = try? await Network.get("recharge/query", query: ["order_id": orderId]) {
                    let paid = d["status"].str == "paid" || d["paid"].bool || d["status"].str == "success"  // 三形态判已付
                    if paid {
                        await MainActor.run {
                            payUrl = nil                     // 关收银台
                            showSuccess = true               // 弹到账提示
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
        SFSafariViewController(url: URL(string: url) ?? URL(fileURLWithPath: "/dev/null"))  // 非法 URL 兜底
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}  // 静态页无需更新
}
