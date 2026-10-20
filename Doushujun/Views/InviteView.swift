import SwiftUI

/// 邀请好友赚次数（对齐安卓 InviteScreen）
struct InviteView: View {
    var onClose: () -> Void
    @State private var info: J? = nil
    @State private var records: [J] = []
    @State private var loading = true
    @State private var error = ""
    @State private var snackbar = ""

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "邀请好友赚次数", back: onClose)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if loading {
                            ProgressView().tint(T.primary).padding(.vertical, 80)
                        } else if let d = info {
                            // 邀请码卡
                            GlassCard {
                                VStack(spacing: 12) {
                                    Text("我的邀请码").font(.system(size: 12)).foregroundColor(T.textSub)
                                    Text(d["invite_code"].str ?? "------")
                                        .font(.system(size: 30, weight: .heavy, design: .monospaced)).foregroundColor(T.primary)
                                        .tracking(4)
                                    HStack(spacing: 10) {
                                        Button { copy(d["invite_code"].str ?? "") } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "doc.on.doc")
                                                Text("复制邀请码").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.bg)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))
                                        }
                                        Button { copy(inviteUrl(d)) } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "link")
                                                Text("复制链接").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.primary)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                                        }
                                    }
                                    if let qr = d["qr_code"].str, qr.hasPrefix("data:image") {
                                        let b64 = qr.replacingOccurrences(of: "^data:image/\\w+;base64,", with: "", options: .regularExpression)
                                        if let img = Data(base64Encoded: b64).flatMap(UIImage.init) {
                                            Image(uiImage: img)
                                                .resizable().interpolation(.none).scaledToFit()
                                                .frame(width: 130, height: 130)
                                                .background(Color.white.cornerRadius(10))
                                            Text("扫码直达注册页").font(.system(size: 11)).foregroundColor(T.textSub)
                                        }
                                    }
                                }
                            }

                            // 奖励规则
                            let rules = d["rules"].arr.compactMap(\.str)
                            if !rules.isEmpty {
                                SectionTitle(text: "奖励规则")
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(rules, id: \.self) { r in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("·").foregroundColor(T.primary)
                                                Text(r).font(.system(size: 13)).foregroundColor(T.textSub)
                                            }
                                        }
                                    }
                                }
                            }

                            // 我的邀请统计
                            SectionTitle(text: "我的邀请")
                            GlassCard {
                                HStack {
                                    MetricCell(value: String(d["total_invited"].int ?? 0), label: "已邀请好友", color: T.primary)
                                    MetricCell(value: String(d["total_reward_points"].int ?? 0), label: "累计奖励点数", color: T.warn)
                                }
                            }

                            // 记录列表
                            SectionTitle(text: "邀请记录")
                            if records.isEmpty {
                                GlassCard { EmptyState(icon: "person.2", text: "暂无邀请记录，快去邀请好友吧") }
                            } else {
                                ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                                    GlassCard(padding: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(r["email_masked"].str ?? r["username"].str ?? "新好友")
                                                    .font(.system(size: 14)).foregroundColor(T.textMain)
                                                Text((r["created_at"].str ?? "").replacingOccurrences(of: "T", with: " "))
                                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                                            }
                                            Spacer()
                                            Text("+\(r["reward_points"].int ?? 0) 点")
                                                .font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        } else {
                            GlassCard { EmptyState(icon: "person.2", text: error.isEmpty ? "加载中…" : error) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .snackbar($snackbar)
        .onAppear { load() }
    }

    private func inviteUrl(_ d: J) -> String {
        let u = d["invite_url"].str ?? ""
        if !u.isEmpty { return u }
        return "https://doushujun.me/register?invite=\(d["invite_code"].str ?? "")"
    }

    private func copy(_ s: String) {
        UIPasteboard.general.string = s
        snackbar = "已复制"
    }

    private func load() {
        Task {
            defer { loading = false }
            info = try? await Network.get("user/invite_info")
            if let d = try? await Network.get("user/invite_records") {
                records = d["list"].arr.isEmpty ? d.arr : d["list"].arr
            }
            if info == nil { error = "加载失败，请稍后重试" }
        }
    }
}
