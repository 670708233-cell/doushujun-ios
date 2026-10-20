import SwiftUI

// ============================================================================
// WorkHistoryView.swift — 作品查询历史页
// 职责：云端记录（分页/刷新/删除）+ 本地记录（SessionStore）双 Tab 列表，
//       条目可回跳作品分析页（对齐安卓 WorkHistoryScreen.kt）
// ============================================================================

/// 作品查询历史（对齐安卓 WorkHistoryScreen.kt：Tab 双列表 + 刷新/删除）
struct WorkHistoryView: View {
    var onBack: () -> Void        // 返回按钮回调（关闭全屏弹层）
    var onQuery: (String) -> Void // 「再查一次」回调：携带 aweme_id 回跳作品分析页

    @State private var tab = 0   // 0=服务端 1=本地
    @State private var list: [J] = []                    // 云端记录列表（J 包装逐条）
    @State private var page = 1                          // 当前已加载页码
    @State private var total = 0                         // 云端总条数（判断是否还有下一页）
    @State private var loading = false                   // 分页加载中标记（防重入）
    @State private var error = ""                        // 首屏错误文案（空态时显示）
    @State private var local: [SessionStore.HistoryEntry] = []  // 本地记录缓存
    @State private var refreshingId: String? = nil       // 正在单条刷新的 aweme_id（转圈定位）
    @State private var snackbar = ""                     // 全局轻提示文案

    var body: some View {
        ZStack {
            TechBackground()                             // 科技感背景层
            VStack(spacing: 0) {
                NavBar(title: "查询历史", back: onBack)   // 顶栏
                tabBar                                   // 云端/本地切换条
                if tab == 0 { serverList } else { localList }  // 按切换显示对应列表
            }
        }
        .snackbar($snackbar)
        .onAppear {
            if tab == 0 && list.isEmpty { load(reset: true) }  // 首次进入拉云端首页
            local = SessionStore.history(SessionStore.workHistoryKey)  // 本地记录即时刷新
        }
    }

    /// 云端/本地分段切换条（选中项渐变胶囊高亮）
    private var tabBar: some View {
        HStack(spacing: 0) {
            segBtn("云端记录", 0)
            segBtn("本地记录", 1)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 单个分段按钮：选中态渐变底+深色字，未选中灰字
    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            if idx == 0 && list.isEmpty { load(reset: true) }  // 首次切回云端补拉
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - 云端列表

    /// 云端记录列表：下拉刷新 + 倒数第二条预加载 + 单条刷新/删除
    private var serverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if list.isEmpty && !loading {            // 空态/错误态
                    EmptyState(icon: "doc.text.magnifyingglass", text: error.isEmpty ? "暂无云端查询记录" : error)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, r in
                    let cover = r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str  // 封面（新结构优先，旧字段兜底）
                    let vid = r["aweme_id"].str ?? ""
                    GlassCard(padding: 12) {
                        HStack(spacing: 12) {
                            Button {                     // 左侧主体：点击回跳分析页
                                onQuery(vid)
                            } label: {
                                HStack(spacing: 12) {
                                    NetImage(url: cover, width: 52, height: 68)   // 竖版封面缩略
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r["desc"].str ?? "未命名作品")          // 作品描述（两行截断）
                                            .font(.system(size: 13)).foregroundColor(T.textMain).lineLimit(2)
                                        Text("账号：\(r["owner_handle"].str ?? "-")")  // 作者昵称
                                            .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                        Text((r["last_query_time"].str ?? "").replacingOccurrences(of: "T", with: " "))  // ISO 时间转可读
                                            .font(.system(size: 11)).foregroundColor(T.textSub)
                                    }
                                }
                            }
                            Spacer()
                            VStack(spacing: 8) {
                                // 刷新：重新拉取该作品数据
                                Button {
                                    refresh(vid)
                                } label: {
                                    if refreshingId == vid {   // 该条刷新中 → 转圈
                                        ProgressView().tint(T.primary).scaleEffect(0.8)
                                    } else {                   // 常态 → 刷新图标
                                        Image(systemName: "arrow.clockwise").font(.system(size: 14)).foregroundColor(T.primary)
                                    }
                                }
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(T.primary.opacity(0.12)))
                                // 删除云端记录
                                Button {
                                    delete(vid)
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(T.danger)
                                }
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(T.danger.opacity(0.12)))
                            }
                        }
                    }
                    .onAppear {
                        if i == list.count - 2 && list.count < total { load(reset: false) }  // 倒数第二条出现且未到总量 → 预加载下一页
                    }
                }
                if loading { ProgressView().tint(T.primary).padding(.vertical, 10) }  // 底部加载指示
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { load(reset: true) }               // 下拉刷新回第一页
    }

    /// 分页拉取云端历史：reset=true 回第一页覆盖，否则追加下一页
    private func load(reset: Bool) {
        if loading { return }                            // 防重入
        loading = true
        if reset { error = "" }                          // 重拉时清旧错误
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/history", body: [
                    "user_email": SessionStore.email,    // 以邮箱定位用户记录
                    "page": reset ? 1 : page + 1,        // 首页或下一页
                    "page_size": 10,
                ])
                let items = d["videos"].arr
                await MainActor.run {
                    total = d["total"].int ?? 0          // 更新总数（预加载判据）
                    page = reset ? 1 : page + 1          // 推进页码
                    list = reset ? items : list + items  // 覆盖或追加
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    /// 单条刷新：调服务端重查该作品并提示结果
    private func refresh(_ vid: String) {
        refreshingId = vid                               // 定位转圈到该条
        Task {
            defer { refreshingId = nil }
            do {
                _ = try await Network.post("v2/query/refresh", body: [
                    "user_email": SessionStore.email, "video_id": vid,
                ])
                await MainActor.run { snackbar = "已刷新该作品数据" }
                load(reset: true)                        // 回首页拿最新数据
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "刷新失败" }
            }
        }
    }

    /// 删除云端记录：成功后本地同步移除并递减总数
    private func delete(_ vid: String) {
        Task {
            do {
                _ = try await Network.post("query/delete", body: [
                    "user_email": SessionStore.email, "video_id": vid,
                ])
                await MainActor.run {
                    list.removeAll { $0["aweme_id"].str == vid }  // 移除该条
                    total = max(0, total - 1)                     // 总数下探（不小于 0）
                    snackbar = "已删除"
                }
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "删除失败" }
            }
        }
    }

    // MARK: - 本地列表

    /// 本地记录列表：SessionStore 持久化的查询足迹，支持再查/单删
    private var localList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if local.isEmpty {                       // 本地空态
                    EmptyState(icon: "clock", text: "暂无本地查询记录")
                }
                ForEach(local) { h in
                    GlassCard(padding: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "link").font(.system(size: 12)).foregroundColor(T.primary)  // 链接图标
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.name.isEmpty ? h.id : h.name)              // 名称缺省显示 ID
                                    .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(1)
                                Text(Fmt.full(Date(timeIntervalSince1970: h.ts / 1000)))  // 查询时间（ms→Date）
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                            Spacer()
                            Button { onQuery(h.id) } label: {  // 再查一次：回跳分析页
                                Text("再查一次").font(.system(size: 12)).foregroundColor(T.primary)
                            }
                            Button {                           // 删除：同步落盘并刷新列表
                                SessionStore.removeHistory(SessionStore.workHistoryKey, id: h.id)
                                local = SessionStore.history(SessionStore.workHistoryKey)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 13)).foregroundColor(T.danger)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
}
