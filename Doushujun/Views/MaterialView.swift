import SwiftUI
import AVKit
import Photos

// ============================================================================
// MaterialView.swift — 取素材页
// 职责：抖音作品链接 → 无水印视频/图集原图解析（旧版 MD5 签名协议）
//       + 播放/保存相册/复制/分享 + 解析历史 chips（对齐安卓 MaterialScreen）
// ============================================================================

/// 取素材页（对齐安卓 MaterialScreen：无水印视频/图集解析 + 保存/复制/分享）
struct MaterialView: View {
    @ObservedObject private var bus = SessionBus.shared

    @State private var input = ""                        // 链接输入框内容
    @State private var loading = false                   // 解析中标记
    @State private var error = ""                        // 解析错误文案
    @State private var result: J? = nil                  // 解析结果（nil=未解析）
    @State private var history: [SessionStore.HistoryEntry] = []  // 本地解析历史
    @State private var playUrl: String? = nil            // 播放中的视频直链（nil=关闭）
    @State private var playTitle = ""                    // 播放弹窗标题
    @State private var snackbar = ""                     // 轻提示
    @State private var saving = false                    // 视频下载保存中
    @State private var imgPage = 0                       // 图集当前页（页码指示）

    var body: some View {
        ZStack {
            TechBackground()                             // 科技感背景
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    AnnouncementBar()                    // 公告栏
                    GradientBanner(title: "取素材", subtitle: "一键解析无水印视频与图集原图")  // 渐变横幅

                    // 输入卡
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("粘贴抖音作品分享链接", text: $input)  // 链接输入
                                .font(.system(size: 14)).foregroundColor(T.textMain)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.stroke, lineWidth: 1))
                            HStack(spacing: 10) {
                                PrimaryButton(title: "开始解析", loading: loading) { parse() }  // 主按钮
                                Button {         // 剪贴板粘贴按钮
                                    if let s = UIPasteboard.general.string, !s.trimmingCharacters(in: .whitespaces).isEmpty {
                                        input = s.trimmingCharacters(in: .whitespaces)  // 回填输入框
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
                            ErrorText(text: error)       // 错误提示行
                        }
                    }

                    // 本地历史 chips
                    if !history.isEmpty {                // 有历史才显示该卡
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(text: "解析历史")
                                ScrollView(.horizontal, showsIndicators: false) {  // 横滑 chips
                                    HStack(spacing: 8) {
                                        ForEach(history.prefix(6)) { h in  // 最多展示 6 条
                                            Button {     // 点 chip：回填并直接解析
                                                input = h.id
                                                parse()
                                            } label: {
                                                Text(h.name.isEmpty ? String(h.id.prefix(16)) : h.name)  // 名称缺省截 ID 前 16 字
                                                    .font(.system(size: 12)).foregroundColor(T.primary)
                                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                                    .background(Capsule().fill(T.primary.opacity(0.10)))
                                                    .overlay(Capsule().stroke(T.primary.opacity(0.3), lineWidth: 1))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Button {         // 清空全部历史
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
                        let videoUrl = d["processed_url"].str            // 无水印视频直链
                        let images = d["images"].arr.compactMap(\.str)   // 图集原图列表
                        let title = d["preview_title"].str ?? "未命名作品"

                        SectionTitle(text: title)
                        if let vu = videoUrl, !vu.isEmpty {              // 视频结果卡
                            GlassCard {
                                VStack(spacing: 10) {
                                    Button {             // 点封面 → 全屏播放
                                        playUrl = vu
                                        playTitle = title
                                    } label: {
                                        ZStack {
                                            NetImage(url: d["cover_url"].str, height: 200)  // 封面
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            Image(systemName: "play.circle.fill")           // 播放角标
                                                .font(.system(size: 48)).foregroundColor(.white.opacity(0.92))
                                        }
                                    }
                                    Text("点击封面播放无水印视频").font(.system(size: 11)).foregroundColor(T.textSub)
                                    HStack(spacing: 10) {
                                        Button { saveVideo(vu, title) } label: {  // 保存视频到相册
                                            HStack(spacing: 5) {
                                                if saving { ProgressView().tint(T.bg) } else { Image(systemName: "square.and.arrow.down") }  // 保存中转圈
                                                Text("保存视频").font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(T.bg)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))
                                        }
                                        .disabled(saving)  // 保存中禁用防重复
                                        Button { copy(vu) } label: {  // 复制直链
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
                        if !images.isEmpty {             // 图集结果卡
                            GlassCard {
                                VStack(spacing: 8) {
                                    TabView(selection: $imgPage) {       // 横滑翻页图集
                                        ForEach(Array(images.enumerated()), id: \.offset) { i, url in
                                            NetImage(url: url, height: 300)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .tag(i)  // 绑定页码
                                        }
                                    }
                                    .tabViewStyle(.page(indexDisplayMode: .never))  // 自绘页码
                                    .frame(height: 300)
                                    Text("\(imgPage + 1) / \(images.count)")        // 页码指示
                                        .font(.system(size: 12)).foregroundColor(T.textSub)
                                    HStack(spacing: 10) {
                                        Button { images.forEach { saveImage($0, title) } } label: {  // 逐张下载全部
                                            HStack(spacing: 5) {
                                                Image(systemName: "square.and.arrow.down")
                                                Text("下载全部图片").font(.system(size: 13))
                                            }
                                            .foregroundColor(T.bg)
                                            .frame(maxWidth: .infinity).frame(height: 42)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(T.grad))
                                        }
                                        Button { copy(images.joined(separator: "\n")) } label: {  // 复制全部图片直链
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
                        if videoUrl == nil && images.isEmpty {           // 啥都没解析到
                            GlassCard { EmptyState(icon: "photo.on.rectangle.angled", text: "未解析到可下载内容") }
                        }

                        // 分享
                        Button {
                            let link = videoUrl ?? images.first ?? ""    // 优先视频，其次首图
                            let text = "【抖数君】已解析无水印素材《\(title)》\n\(link)\n——来自抖数君APP"
                            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)  // 系统分享面板
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
        .onAppear { history = SessionStore.history(SessionStore.materialHistoryKey) }  // 进页刷新历史
        .fullScreenCover(isPresented: Binding(get: { playUrl != nil }, set: { if !$0 { playUrl = nil } })) {
            InlinePlayer(url: playUrl ?? "", title: playTitle) { playUrl = nil }  // 全屏播放弹窗
        }
    }

    /// 复制文本到剪贴板并提示
    private func copy(_ s: String) {
        UIPasteboard.general.string = s
        snackbar = "链接已复制"
    }

    // MARK: - 解析（旧版 MD5 签名协议）

    /// 解析入口：提链接 → 提 ID → legacySign 签名 → 请求无水印接口
    private func parse() {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { error = "请输入分享链接"; return }   // 空输入拦截
        let target = LinkParser.extractVideoTarget(raw)               // 文案中提视频 ID
        guard let vid = target.id else { error = "无法识别作品ID，请检查链接"; return }
        loading = true
        error = ""
        Task {
            defer { loading = false }
            do {
                let sig = Crypto.legacySign(awemeId: vid)             // 旧版时间戳+nonce+MD5 签名
                let d = try await Network.post("tools/video/remove_watermark", body: [
                    "input": vid,
                    "timestamp": Int64(sig.timestamp) ?? 0,
                    "nonce": sig.nonce,
                    "signature": sig.signature,
                ])
                await MainActor.run {
                    result = d
                    imgPage = 0                                       // 图集回第一页
                    SessionStore.pushHistory(SessionStore.materialHistoryKey, id: vid,  // 记入历史
                                             name: d["preview_title"].str ?? "")
                    history = SessionStore.history(SessionStore.materialHistoryKey)
                }
            } catch {
                await MainActor.run { self.error = (error as? ApiError)?.errorDescription ?? "解析失败" }
            }
        }
    }

    // MARK: - 保存（相册权限 + URL 下载）

    /// 保存视频：下载完成后写相册（视频类型）
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

    /// 保存单张图片：下载完成后写相册（图片类型）
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
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")  // 伪装浏览器 UA
        req.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")  // 抖音 referer 防 CDN 拒链
        URLSession.shared.dataTask(with: req) { data, _, _ in done(data) }.resume()
    }

    /// 写入相册：addOnly 权限 → 视频落临时文件建 Asset / 图片直接建 Asset
    private func saveToPhotos(url: String, data: Data, isVideo: Bool) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { st in    // 仅写入权限
            guard st == .authorized || st == .limited else {
                DispatchQueue.main.async { snackbar = "无相册权限，请在设置中开启" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                if isVideo {                                          // 视频：先落临时 mp4 再入库
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent("dsj_\(UUID().uuidString.prefix(6)).mp4")
                    try? data.write(to: tmp)
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp)
                } else {                                              // 图片：直接从 Data 建 Asset
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
    let url: String                // 视频直链
    let title: String              // 顶部标题
    var onDismiss: () -> Void      // 关闭回调

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()                // 纯黑底
            VideoPlayer(player: AVPlayer(url: URL(string: url) ?? URL(fileURLWithPath: "/dev/null")))  // 播放器（非法 URL 兜底空设备）
                .ignoresSafeArea()
            HStack {
                Button(action: onDismiss) {              // 关闭按钮
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26)).foregroundColor(.white.opacity(0.85))
                }
                Text(title).font(.system(size: 13)).foregroundColor(.white.opacity(0.85)).lineLimit(1)  // 标题一行
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
