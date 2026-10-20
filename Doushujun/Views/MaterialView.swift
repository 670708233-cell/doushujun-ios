import SwiftUI
import AVKit
import Photos

/// 取素材页（对齐安卓 MaterialScreen：无水印视频/图集解析 + 保存/复制/分享）
struct MaterialView: View {
    @ObservedObject private var bus = SessionBus.shared

    @State private var input = ""
    @State private var loading = false
    @State private var error = ""
    @State private var result: J? = nil
    @State private var history: [SessionStore.HistoryEntry] = []
    @State private var playUrl: String? = nil
    @State private var playTitle = ""
    @State private var snackbar = ""
    @State private var saving = false
    @State private var imgPage = 0

    var body: some View {
        ZStack {
            TechBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()
                    GradientBanner(title: "取素材", subtitle: "一键解析无水印视频与图集原图")

                    // 输入卡
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("粘贴抖音作品分享链接", text: $input)
                                .font(.system(size: 14)).foregroundColor(T.textMain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                            HStack(spacing: 10) {
                                PrimaryButton(title: "开始解析", loading: loading) { parse() }
                                Button {
                                    if let s = UIPasteboard.general.string, !s.trimmingCharacters(in: .whitespaces).isEmpty {
                                        input = s.trimmingCharacters(in: .whitespaces)
                                        snackbar = "已粘贴，点击「开始解析」"
                                    } else {
                                        snackbar = "剪贴板是空的，先去复制分享链接吧"
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(T.primary).frame(width: 48, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(T.primary.opacity(0.12)))
                                }
                            }
                            ErrorText(text: error)
                        }
                    }

                    // 本地历史 chips
                    if !history.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(text: "解析历史")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(history.prefix(6)) { h in
                                            Button {
                                                input = h.id
                                                parse()
                                            } label: {
                                                Text(h.name.isEmpty ? String(h.id.prefix(16)) : h.name)
                                                    .font(.system(size: 12)).foregroundColor(T.primary)
                                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                                    .background(Capsule().fill(T.primary.opacity(0.10)))
                                                    .overlay(Capsule().stroke(T.primary.opacity(0.3), lineWidth: 1))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Button {
                                            history.forEach { SessionStore.removeHistory(SessionStore.materialHistoryKey, id: $0.id) }
                                            history = []
                                            snackbar = "历史已清空"
                                        } label: {
                                            Image(systemName: "trash").font(.system(size: 12)).foregroundColor(T.danger)
                                                .padding(9)
                                                .background(Circle().fill(T.danger.opacity(0.10)))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 结果区
                    if let d = result {
                        let videoUrl = d["processed_url"].str
                        let images = d["images"].arr.compactMap(\.str)
                        let title = d["preview_title"].str ?? "未命名作品"

                        SectionTitle(text: title)
                        if let vu = videoUrl, !vu.isEmpty {
                            GlassCard {
                                VStack(spacing: 10) {
                                    Button {
                                        playUrl = vu
                                        playTitle = title
                                    } label: {
                                        ZStack {
                                            NetImage(url: d["cover_url"].str, height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 48)).foregroundColor(.white.opacity(0.92))
                                        }
                                    }
                                    Text("点击封面播放无水印视频").font(.system(size: 11)).foregroundColor(T.textSub)
                                    HStack(spacing: 10) {
                                        Button { saveVideo(vu, title) } label: {
                                            HStack(spacing: 5) {
                                                if saving { ProgressView().tint(T.bg) } else { Image(systemName: "square.and.arrow.down") }
                                                Text("保存视频").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.bg)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))
                                        }
                                        .disabled(saving)
                                        Button { copy(vu) } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "doc.on.doc")
                                                Text("复制链接").font(.system(size: 13))
                                            }
                                            .foregroundColor(T.primary)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                                        }
                                    }
                                }
                            }
                        }
                        if !images.isEmpty {
                            GlassCard {
                                VStack(spacing: 8) {
                                    TabView(selection: $imgPage) {
                                        ForEach(Array(images.enumerated()), id: \.offset) { i, url in
                                            NetImage(url: url, height: 300)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .tag(i)
                                        }
                                    }
                                    .tabViewStyle(.page(indexDisplayMode: .never))
                                    .frame(height: 300)
                                    Text("\(imgPage + 1) / \(images.count)")
                                        .font(.system(size: 12)).foregroundColor(T.textSub)
                                    HStack(spacing: 10) {
                                        Button { images.forEach { saveImage($0, title) } } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "square.and.arrow.down")
                                                Text("下载全部图片").font(.system(size: 13))
                                            }
                                            .foregroundColor(T.bg)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))
                                        }
                                        Button { copy(images.joined(separator: "\n")) } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "doc.on.doc")
                                                Text("复制链接").font(.system(size: 13))
                                            }
                                            .foregroundColor(T.primary)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.primary.opacity(0.12)))
                                        }
                                    }
                                }
                            }
                        }
                        if videoUrl == nil && images.isEmpty {
                            GlassCard { EmptyState(icon: "photo.on.rectangle.angled", text: "未解析到可下载内容") }
                        }

                        // 分享
                        Button {
                            let link = videoUrl ?? images.first ?? ""
                            let text = "【抖数君】已解析无水印素材《\(title)》\n\(link)\n——来自抖数君APP"
                            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                            UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
                        } label: {
                            GlassCard(padding: 14) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up").foregroundColor(T.primary)
                                    Text("分享给好友").font(.system(size: 14)).foregroundColor(T.textMain)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(T.textSub)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .snackbar($snackbar)
        .onAppear { history = SessionStore.history(SessionStore.materialHistoryKey) }
        .fullScreenCover(isPresented: Binding(get: { playUrl != nil }, set: { if !$0 { playUrl = nil } })) {
            InlinePlayer(url: playUrl ?? "", title: playTitle) { playUrl = nil }
        }
    }

    private func copy(_ s: String) {
        UIPasteboard.general.string = s
        snackbar = "链接已复制"
    }

    // MARK: - 解析（旧版 MD5 签名协议）

    private func parse() {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请输入分享链接"; return }
        let target = LinkParser.extractVideoTarget(raw)
        guard let vid = target.id else { error = "无法识别作品ID，请检查链接"; return }
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                let sig = Crypto.legacySign(awemeId: vid)
                let d = try await Network.post("tools/video/remove_watermark", body: [
                    "input": vid,
                    "timestamp": Int64(sig.timestamp) ?? 0,
                    "nonce": sig.nonce,
                    "signature": sig.signature,
                ])
                await MainActor.run {
                    result = d
                    imgPage = 0
                    SessionStore.pushHistory(SessionStore.materialHistoryKey, id: vid,
                                             name: d["preview_title"].str ?? "")
                    history = SessionStore.history(SessionStore.materialHistoryKey)
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "解析失败" }
            }
        }
    }

    // MARK: - 保存（相册权限 + URL 下载）

    private func saveVideo(_ url: String, _ title: String) {
        saving = true
        snackbar = "开始下载视频…"
        downloadData(url) { data in
            DispatchQueue.main.async {
                saving = false
                guard let data = data else { snackbar = "下载失败"; return }
                saveToPhotos(url: url, data: data, isVideo: true)
            }
        }
    }

    private func saveImage(_ url: String, _ title: String) {
        downloadData(url) { data in
            DispatchQueue.main.async {
                guard let data = data else { snackbar = "图片下载失败"; return }
                saveToPhotos(url: url, data: data, isVideo: false)
            }
        }
    }

    /// 短视频 CDN 需要 UA/Referer 头
    private func downloadData(_ url: String, done: @escaping (Data?) -> Void) {
        guard let u = URL(string: url) else { done(nil); return }
        var req = URLRequest(url: u)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
        URLSession.shared.dataTask(with: req) { data, _, _ in done(data) }.resume()
    }

    private func saveToPhotos(url: String, data: Data, isVideo: Bool) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { st in
            guard st == .authorized || st == .limited else {
                DispatchQueue.main.async { snackbar = "无相册权限，请在设置中开启" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                if isVideo {
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent("dsj_\(UUID().uuidString.prefix(6)).mp4")
                    try? data.write(to: tmp)
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp)
                } else {
                    PHAssetChangeRequest.creationRequestForAsset(from: UIImage(data: data) ?? UIImage())
                }
            } completionHandler: { ok, _ in
                DispatchQueue.main.async { snackbar = ok ? "已保存到相册" : "保存失败" }
            }
        }
    }
}

/// 内联播放器（对齐安卓 InlineVideoPlayer：全屏弹窗播无水印直链）
struct InlinePlayer: View {
    let url: String
    let title: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: URL(string: url) ?? URL(fileURLWithPath: "/dev/null")))
                .ignoresSafeArea()
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26)).foregroundColor(.white.opacity(0.85))
                }
                Text(title).font(.system(size: 13)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                Spacer()
            }
            .padding(14)
        }
        .onAppear {
            // 自动播放
            NotificationCenter.default.post(name: Notification.Name("AVPlayerItemDidPlayToEndTime"), object: nil)
        }
    }
}
