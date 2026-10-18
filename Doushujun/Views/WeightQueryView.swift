import SwiftUI

// ============================================================================
// WeightQueryView —— 查权重（web 端 v2/query/weight 同款）
// 输入抖音主页链接/抖音号 → 权重分/活跃度/健康度 + 明细指标 + 余额扣减展示
// ============================================================================

struct WeightQueryView: View {

    @EnvironmentObject private var store: UserStore   // 全局状态（邮箱/余额）

    // MARK: - 状态

    @State private var input = ""                     // 用户输入（链接/抖音号）
    @State private var isLoading = false              // 查询中
    @State private var errorMessage = ""              // 错误提示
    @State private var result: WeightResult?          // 查询结果
    @State private var appeared = false               // 入场动画开关

    /// 查询结果模型（视图专用，解析自 weight_info）
    struct WeightResult {
        var nickname: String                          // 昵称
        var account: String                           // 抖号
        var weightScore: String                       // 权重分
        var activity: String                          // 活跃度
        var health: String                            // 健康度
        var avatarUrl: String                         // 头像
        var desc: String                              // 权重描述
        var rowInfo: [(String, String)]               // 明细指标 [(名, 值)]
        var newBalance: String                        // 查询后余额
        var remainingQueries: String                  // 剩余可查次数
    }

    var body: some View {
        ZStack {
            CyberBackground()                              // 统一深空背景

            ScrollView {
                VStack(spacing: 16) {

                    // ---- 顶部标题区 ----
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("账号权重查询")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .gradientText(Theme.cyber)          // 渐变标题
                            Text("分析抖音账号的权重/活跃/健康状态")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSub)
                        }
                        Spacer()
                        // 余额胶囊（实时）
                        HStack(spacing: 5) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 11))
                            Text(String(format: "%.2f", store.balance))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.green.opacity(0.12)))
                        .overlay(Capsule().stroke(Theme.green.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // ---- 输入卡 ----
                    VStack(spacing: 14) {
                        SectionHeader(icon: "link.badge.plus", title: "查询目标")

                        // 多行输入框（链接可能较长）：玻璃样式 + 渐变聚焦描边
                        TextField("粘贴抖音主页链接，如 https://v.douyin.com/xxx",
                                  text: $input, axis: .vertical)
                            .lineLimit(2...4)                       // 2~4 行自适应
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(input.isEmpty ? Theme.cardStroke : Theme.blue.opacity(0.5), lineWidth: 1)
                            )

                        // 查询主按钮（发光渐变）
                        Button {
                            Task { await query() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white)
                                    Text("查询中，约需数秒...")
                                } else {
                                    Image(systemName: "wand.and.stars") // 魔法棒图标
                                    Text("开始查询")
                                }
                            }
                        }
                        .buttonStyle(GlowButtonStyle(gradient: Theme.cyber, height: 50))
                        .disabled(isLoading || input.isEmpty)           // 空输入/请求中禁用

                        // 错误提示
                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13)).foregroundStyle(Theme.red)
                                Text(errorMessage).font(.system(size: 13)).foregroundColor(Theme.red)
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.10)))
                        }
                    }
                    .glassCard(radius: 22, padding: 18)
                    .padding(.horizontal, 18)

                    // ---- 结果卡（有结果才显示）----
                    if let r = result {
                        resultCard(r)
                            .transition(.opacity.combined(with: .move(edge: .bottom))) // 底部滑入
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
        // 入场动画
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - 结果卡片

    private func resultCard(_ r: WeightResult) -> some View {
        VStack(spacing: 14) {

            // ---- 用户信息行：头像 + 昵称 + 抖号 ----
            HStack(spacing: 12) {
                if let url = URL(string: r.avatarUrl), !r.avatarUrl.isEmpty {
                    AsyncImage(url: url) { image in                    // 异步加载头像
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.08))       // 加载占位
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.cyan.opacity(0.6), lineWidth: 1.5)) // 霓虹头像描边
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.nickname.isEmpty ? "-" : r.nickname)        // 昵称
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textMain)
                    Text(r.account.isEmpty ? "-" : "@\(r.account)")    // 抖号
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSub)
                }
                Spacer()
            }

            // ---- 三大评分：权重分/活跃度/健康度 ----
            HStack(spacing: 10) {
                scoreTile(title: "权重分", value: r.weightScore, icon: "gauge.with.needle", tint: Theme.amber)
                scoreTile(title: "活跃度", value: r.activity, icon: "bolt.fill", tint: Theme.green)
                scoreTile(title: "健康度", value: r.health, icon: "heart.text.square.fill", tint: Theme.cyan)
            }

            // ---- 明细指标列表 ----
            if !r.rowInfo.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                VStack(spacing: 8) {
                    ForEach(r.rowInfo, id: \.0) { pair in
                        HStack {
                            Text(pair.0)                               // 指标名
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSub)
                            Spacer()
                            Text(pair.1)                               // 指标值（等宽字对齐）
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.textMain)
                        }
                    }
                }
            }

            // ---- 权重描述 ----
            if !r.desc.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                Text(r.desc)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ---- 底部：余额与剩余次数 ----
            Divider().background(Color.white.opacity(0.08))
            HStack {
                Label("余额 ¥\(r.newBalance)", systemImage: "creditcard")
                Spacer()
                Label("剩余 \(r.remainingQueries) 次", systemImage: "number")
            }
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundColor(Theme.textDim)
        }
        .glassCard(radius: 22, padding: 18)
        .padding(.horizontal, 18)
    }

    /// 单个评分块：图标 + 大号渐变数字 + 标题
    private func scoreTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)                                // 指标图标
                .font(.system(size: 13))
                .foregroundColor(tint)
            Text(value.isEmpty ? "-" : value)                      // 分数（大号等宽）
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .gradientText(LinearGradient(colors: [tint, tint.opacity(0.65)],
                                             startPoint: .top, endPoint: .bottom))
            Text(title)                                            // 指标名
                .font(.system(size: 11.5))
                .foregroundColor(Theme.textSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))                          // 同色淡底
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)          // 同色描边
        )
        .shadow(color: tint.opacity(0.25), radius: 8, y: 2)        // 霓虹微光
    }

    // MARK: - 查询

    private func query() async {
        errorMessage = ""
        result = nil
        guard !input.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // POST /v2/query/weight（JWT + 签名）
            let d = try await API.queryWeight(userEmail: store.email, input: input)
            if let r = parse(d) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    result = r                                   // 结果滑入动画
                }
            }
            if let nb = API.toDouble(d["new_balance"]) { store.balance = nb } // 同步余额
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 解析 weight_info（兼容内层 code/data 再嵌套一层的情况）
    private func parse(_ d: [String: Any]) -> WeightResult? {
        var wi = d["weight_info"] as? [String: Any]                  // 直接取
        if wi == nil, let inner = d["data"] as? [String: Any] {
            wi = inner["weight_info"] as? [String: Any]              // 内层 data 再取
        }
        guard var w = wi else {
            errorMessage = "未获取到权重数据"
            return nil
        }
        // weight_info 内可能还包一层 {code, data:{...}}：把内层字段上提
        if let nested = w["data"] as? [String: Any] {
            for (k, v) in nested where w[k] == nil { w[k] = v }
        }
        // 明细指标字典转数组并按键名排序
        var rowInfo: [(String, String)] = []
        if let ri = w["rowInfo"] as? [String: Any] {
            rowInfo = ri.map { (API.toStr($0.key), API.toStr($0.value)) }.sorted { $0.0 < $1.0 }
        }
        return WeightResult(
            nickname: API.toStr(w["nickname"]),
            account: API.toStr(w["account"]),
            weightScore: pretty(API.toStr(w["weightScore"])),
            activity: pretty(API.toStr(w["activity"])),
            health: pretty(API.toStr(w["health"])),
            avatarUrl: API.toStr(w["avatarUrl"]),
            desc: API.toStr(w["desc"]),
            rowInfo: rowInfo,
            newBalance: API.toStr(d["new_balance"], fallback: String(format: "%.2f", store.balance)),
            remainingQueries: API.toStr(d["remaining_queries"], fallback: "-")
        )
    }

    /// 分数美化：整数去小数点，小数保留 1 位
    private func pretty(_ s: String) -> String {
        guard !s.isEmpty, let d = Double(s) else { return s }
        return d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}
