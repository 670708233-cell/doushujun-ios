import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: UserStore

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // 顶部标题
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("会员中心")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Text("用户ID：\(store.userId)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))
                        }
                        Spacer()
                        Button(action: { Task { _ = await store.refreshVip(showLoading: true) } }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Color(red: 0.13, green: 0.18, blue: 0.3))
                                .clipShape(Circle())
                        }
                        .disabled(store.isLoadingVip)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // VIP 状态卡
                    vipCard

                    // 权益列表
                    VStack(alignment: .leading, spacing: 14) {
                        Text("会员权益")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        benefitRow(icon: "chart.bar.fill", title: "查账号权重", desc: "每日限额内无限查询")
                        benefitRow(icon: "wand.and.stars", title: "查作品优化建议", desc: "AI 分析作品数据")
                        benefitRow(icon: "square.and.arrow.down.fill", title: "取素材", desc: "无限制获取抖音素材")
                        benefitRow(icon: "chart.line.uptrend.xyaxis", title: "作品数据监控", desc: "数据趋势实时监控")
                    }
                    .padding(18)
                    .background(Color(red: 0.09, green: 0.13, blue: 0.22))
                    .cornerRadius(18)
                    .padding(.horizontal, 20)

                    if !(store.vipStatus?.isVip ?? false) {
                        NavigationLink(destination: RechargeView()) {
                            Text("立即开通会员")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(LinearGradient(colors: [Color(red: 0.95, green: 0.62, blue: 0.24),
                                                                    Color(red: 0.93, green: 0.42, blue: 0.24)],
                                                           startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            if store.vipStatus == nil {
                await store.refreshVip()
            }
        }
    }

    private var vipCard: some View {
        let status = store.vipStatus
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: status?.isVip == true ? "crown.fill" : "crown")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.35))
                Text(status?.isVip == true ? "VIP 会员" : "普通用户")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if status?.isVip == true {
                    Text(status?.packageName ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(10)
                }
            }

            if status?.isVip == true {
                Divider().background(Color.white.opacity(0.15))
                infoRow(label: "套餐类型", value: status?.packageName ?? "-")
                infoRow(label: "剩余天数", value: status?.remainText ?? "-")
                let period = "\(status?.startTime ?? "-") 至 \(status?.isPermanent == true ? "永久" : (status?.endTime ?? "-"))"
                infoRow(label: "有效期", value: period)
            } else {
                Text("开通会员解锁全部功能\n支付完成后权益立即生效")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.72, green: 0.79, blue: 0.92))
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: status?.isVip == true
                                   ? [Color(red: 0.36, green: 0.28, blue: 0.1), Color(red: 0.18, green: 0.15, blue: 0.06)]
                                   : [Color(red: 0.12, green: 0.17, blue: 0.3), Color(red: 0.09, green: 0.13, blue: 0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(status?.isVip == true ? Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.78, green: 0.8, blue: 0.75))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func benefitRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.4, green: 0.55, blue: 1.0))
                .frame(width: 36, height: 36)
                .background(Color(red: 0.4, green: 0.55, blue: 1.0).opacity(0.12))
                .cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.5, green: 0.58, blue: 0.75))
            }
            Spacer()
        }
    }
}
