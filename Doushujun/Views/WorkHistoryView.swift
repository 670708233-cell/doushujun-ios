import SwiftUI

/// 作品查询历史（对齐安卓 WorkHistoryScreen.kt：Tab 双列表 + 刷新/删除）
struct WorkHistoryView: View {
    var onBack: () -> Void
    var onQuery: (String) -> Void

    @State private var tab = 0   // 0=服务端 1=本地
    @State private var list: [J] = []
    @State private var page = 1
    @State private var total = 0
    @State private var loading = false
    @State private var error = ""
    @State private var local: [SessionStore.HistoryEntry] = []
    @State private var refreshingId: String? = nil
    @State private var snackbar = ""

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 0) {
                NavBar(title: "查询历史", back: onBack)
                tabBar
                if tab == 0 { serverList } else { localList }
            }
        }
        .snackbar($snackbar)
        .onAppear {
            if tab == 0 && list.isEmpty { load(reset: true) }
            local = SessionStore.history(SessionStore.workHistoryKey)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            segBtn("云端记录", 0)
            segBtn("本地记录", 1)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func segBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            tab = idx
            if idx == 0 && list.isEmpty { load(reset: true) }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tab == idx ? T.bg : T.textSub)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(tab == idx ? AnyShapeStyle(T.grad) : AnyShapeStyle(.clear)))
        }
    }

    // MARK: - 云端列表

    private var serverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if list.isEmpty && !loading {
                    EmptyState(icon: "doc.text.magnifyingglass", text: error.isEmpty ? "暂无云端查询记录" : error)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, r in
                    let cover = r["cover_info"]["default_cover"].str ?? r["aweme_cover"].str
                    let vid = r["aweme_id"].str ?? ""
                    GlassCard(padding: 12) {
                        HStack(spacing: 12) {
                            Button {
                                onQuery(vid)
                            } label: {
                                HStack(spacing: 12) {
                                    NetImage(url: cover, width: 52, height: 68)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r["desc"].str ?? "未命名作品")
                                            .font(.system(size: 13)).foregroundColor(T.textMain).lineLimit(2)
                                        Text("账号：\(r["owner_handle"].str ?? "-")")
                                            .font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                                        Text((r["last_query_time"].str ?? "").replacingOccurrences(of: "T", with: " "))
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
                                    if refreshingId == vid {
                                        ProgressView().tint(T.primary).scaleEffect(0.8)
                                    } else {
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
                        if i == list.count - 2 && list.count < total { load(reset: false) }
                    }
                }
                if loading { ProgressView().tint(T.primary).padding(.vertical, 10) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { load(reset: true) }
    }

    private func load(reset: Bool) {
        if loading { return }
        loading = true
        if reset { error = "" }
        Task {
            defer { loading = false }
            do {
                let d = try await Network.post("v2/query/history", body: [
                    "user_email": SessionStore.email,
                    "page": reset ? 1 : page + 1,
                    "page_size": 10,
                ])
                let items = d["videos"].arr
                await MainActor.run {
                    total = d["total"].int ?? 0
                    page = reset ? 1 : page + 1
                    list = reset ? items : list + items
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "加载失败" }
            }
        }
    }

    private func refresh(_ vid: String) {
        refreshingId = vid
        Task {
            defer { refreshingId = nil }
            do {
                _ = try await Network.post("v2/query/refresh", body: [
                    "user_email": SessionStore.email, "video_id": vid,
                ])
                await MainActor.run { snackbar = "已刷新该作品数据" }
                load(reset: true)
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "刷新失败" }
            }
        }
    }

    private func delete(_ vid: String) {
        Task {
            do {
                _ = try await Network.post("query/delete", body: [
                    "user_email": SessionStore.email, "video_id": vid,
                ])
                await MainActor.run {
                    list.removeAll { $0["aweme_id"].str == vid }
                    total = max(0, total - 1)
                    snackbar = "已删除"
                }
            } catch {
                await MainActor.run { snackbar = (error as? ApiError)?.errorDescription ?? "删除失败" }
            }
        }
    }

    // MARK: - 本地列表

    private var localList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if local.isEmpty {
                    EmptyState(icon: "clock", text: "暂无本地查询记录")
                }
                ForEach(local) { h in
                    GlassCard(padding: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "link").font(.system(size: 12)).foregroundColor(T.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.name.isEmpty ? h.id : h.name)
                                    .font(.system(size: 14)).foregroundColor(T.textMain).lineLimit(1)
                                Text(Fmt.full(Date(timeIntervalSince1970: h.ts / 1000)))
                                    .font(.system(size: 11)).foregroundColor(T.textSub)
                            }
                            Spacer()
                            Button { onQuery(h.id) } label: {
                                Text("再查一次").font(.system(size: 12)).foregroundColor(T.primary)
                            }
                            Button {
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
