import SwiftUI

/// 查权重（web 端 v2/query/weight 同款）
struct WeightQueryView: View {
    @EnvironmentObject private var store: UserStore

    @State private var input = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var result: WeightResult?

    struct WeightResult {
        var nickname: String
        var account: String
        var weightScore: String
        var activity: String
        var health: String
        var avatarUrl: String
        var desc: String
        var rowInfo: [(String, String)]
        var newBalance: String
        var remainingQueries: String
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    // 输入卡
                    VStack(spacing: 12) {
                        HStack {
                            Text("抖音主页链接 / 抖号 / sec_uid")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        TextField("粘贴抖音主页链接，如 https://v.douyin.com/xxx",
                                  text: $input, axis: .vertical)
                            .lineLimit(2...4)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.28))
                            .cornerRadius(10)

                        Button(action: { Task { await query() } }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                    Text("查询中，约需数秒...")
                                        .font(.system(size: 15, weight: .semibold))
                                } else {
                                    Image(systemName: "magnifyingglass")
                                    Text("查询权重")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                Color(red: 0.42, green: 0.36, blue: 0.95)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || input.isEmpty)

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // 结果
                    if let r = result {
                        resultCard(r)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("账号权重查询")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("余额 ¥\(String(format: "%.2f", store.balance))")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 26))
                .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func resultCard(_ r: WeightResult) -> some View {
        VStack(spacing: 14) {
            // 用户信息
            HStack(spacing: 12) {
                if let url = URL(string: r.avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(red: 0.15, green: 0.2, blue: 0.33)
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.nickname.isEmpty ? "-" : r.nickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(r.account.isEmpty ? "-" : "@\(r.account)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
                }
                Spacer()
            }

            // 三个分数
            HStack(spacing: 10) {
                scoreTile(title: "权重分", value: r.weightScore,
                          color: Color(red: 0.95, green: 0.62, blue: 0.24))
                scoreTile(title: "活跃度", value: r.activity,
                          color: Color(red: 0.3, green: 0.75, blue: 0.42))
                scoreTile(title: "健康度", value: r.health,
                          color: Color(red: 0.4, green: 0.55, blue: 1.0))
            }

            // 明细指标
            if !r.rowInfo.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                VStack(spacing: 8) {
                    ForEach(r.rowInfo, id: \.0) { pair in
                        HStack {
                            Text(pair.0)
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                            Spacer()
                            Text(pair.1)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            if !r.desc.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                Text(r.desc)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.white.opacity(0.08))
            HStack {
                Text("本次余额：¥\(r.newBalance)")
                Spacer()
                Text("剩余次数：\(r.remainingQueries)")
            }
            .font(.system(size: 12))
            .foregroundColor(Color(red: 0.55, green: 0.65, blue: 0.85))
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.13, blue: 0.22))
        .cornerRadius(18)
        .padding(.horizontal, 16)
    }

    private func scoreTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.6, green: 0.66, blue: 0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 查询

    private func query() async {
        errorMessage = ""
        result = nil
        guard !input.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let d = try await API.queryWeight(userEmail: store.email, input: input)
            result = parse(d)
            if let nb = API.toDouble(d["new_balance"]) { store.balance = nb }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 解析 weight_info（兼容内层 code/data 再嵌套一层的情况）
    private func parse(_ d: [String: Any]) -> WeightResult? {
        var wi = d["weight_info"] as? [String: Any]
        if wi == nil, let inner = d["data"] as? [String: Any] {
            wi = inner["weight_info"] as? [String: Any]
        }
        guard var w = wi else {
            errorMessage = "未获取到权重数据"
            return nil
        }
        // weight_info 内可能还有 {code, data:{...}}
        if let nested = w["data"] as? [String: Any] {
            for (k, v) in nested {
                if w[k] == nil { w[k] = v }
            }
        }

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

    private func pretty(_ s: String) -> String {
        guard !s.isEmpty, let d = Double(s) else { return s }
        return d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}
