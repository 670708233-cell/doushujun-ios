import SwiftUI  // UI 框架

// MARK: - 网络图片（列表封面/头像）

/// 异步网络图片：NSCache 内存缓存 + 占位加载动画 + 防串图保护
struct NetImage: View {
    let url: String?            // 图片地址（nil/空显示占位）
    var width: CGFloat? = nil   // 显示宽（nil 自适应）
    var height: CGFloat? = nil  // 显示高

    @State private var img: UIImage? = nil  // 已加载的图片（nil=加载中）

    /// 全局内存缓存（URL→UIImage，自动响应内存告警清空）
    private static let cache = NSCache<NSString, UIImage>()

    /// 标准构造：URL + 可选宽高
    init(url: String?, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.url = url
        self.width = width
        self.height = height
    }

    /// 正方形便捷构造（头像等）
    init(url: String?, size: CGFloat) {
        self.init(url: url, width: size, height: size)  // 宽高同值
    }

    var body: some View {
        Group {
            if let img = img {                                       // 已加载：
                Image(uiImage: img).resizable().scaledToFill()       // 填充裁剪显示
            } else {                                                 // 加载中：
                ZStack {                                             // 占位容器
                    T.cardHi                                         // 占位底色
                    ProgressView().scaleEffect(0.7).tint(T.textSub)  // 小号转圈
                }
            }
        }
        .frame(width: width, height: height)  // 定尺寸
        .clipped()                            // 超界裁剪（fill 模式必需）
        .onAppear { load() }                  // 出现时触发加载
    }

    /// 加载流程：缓存命中直取，未命中发起下载后写缓存
    private func load() {
        guard let u = url, !u.isEmpty, img == nil else { return }  // 无地址或已加载：跳过
        if let hit = Self.cache.object(forKey: u as NSString) {    // 缓存命中：
            img = hit                                              // 直接显示
            return
        }
        guard let req = URL(string: u) else { return }             // URL 非法：放弃
        URLSession.shared.dataTask(with: req) { data, _, _ in      // 后台下载
            guard let data = data, let im = UIImage(data: data) else { return }  // 解码失败：放弃
            Self.cache.setObject(im, forKey: u as NSString)        // 写入缓存
            DispatchQueue.main.async {                             // 切主线程更新 UI
                // 仅当仍展示同一 URL 时更新（复用场景防串图）
                if url == u { img = im }                           // 视图已复用为他图：丢弃
            }
        }.resume()                                                 // 启动任务
    }
}

// MARK: - 公告条（bus.announcement 有内容时显示）

/// 顶部公告条：喇叭图标+单行正文，警示色淡底
struct AnnouncementBar: View {
    @ObservedObject private var bus = SessionBus.shared  // 观察总线（公告变化即刷新）

    var body: some View {
        if let a = bus.announcement {                     // 有公告才渲染
            HStack(spacing: 8) {                          // 图标+正文横排
                Image(systemName: "speaker.wave.2.fill")  // 喇叭图标
                    .font(.system(size: 12)).foregroundColor(T.warn)
                Text(a.content)                           // 公告正文（单行截断）
                    .font(.system(size: 12)).foregroundColor(T.textSub)
                    .lineLimit(1)
                Spacer(minLength: 0)                      // 靠左排布
            }
            .padding(.horizontal, 12).padding(.vertical, 8)                                    // 内边距
            .background(RoundedRectangle(cornerRadius: 10).fill(T.warn.opacity(0.10)))         // 警示色淡底
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.warn.opacity(0.25), lineWidth: 1))  // 同色描边
        }
    }
}

// MARK: - 渐变横幅（页头标题区）

/// 页头横幅：渐变方块图标 + 主/副标题，淡渐变底+描边
struct GradientBanner: View {
    let title: String            // 主标题
    var subtitle: String = ""    // 副标题（可空）

    var body: some View {
        HStack(spacing: 12) {    // 图标+文字横排
            RoundedRectangle(cornerRadius: 10)              // 图标底座
                .fill(T.grad)                               // 品牌渐变
                .frame(width: 42, height: 42)               // 固定 42 见方
                .overlay(Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold)).foregroundColor(.white))  // 白色闪电图标
            VStack(alignment: .leading, spacing: 3) {       // 文字纵排
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(T.textMain)  // 主标题
                if !subtitle.isEmpty {                      // 副标题非空才显示
                    Text(subtitle).font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)  // 单行小字
                }
            }
            Spacer(minLength: 0)                            // 内容靠左
        }
        .padding(14)                                        // 内边距
        .background(                                        // 淡品牌渐变底
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [T.primary.opacity(0.10), T.secondary.opacity(0.10)],
                                     startPoint: .leading, endPoint: .trailing))  // 左→右 10% 透明渐变
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.stroke, lineWidth: 1))  // 描边
    }
}

// MARK: - Snackbar（.snackbar($text)：非空即显示，2.4s 自动消失）

/// 底部悬浮提示条：文本非空显示，2.4 秒后自动清空绑定值
struct SnackbarHost: View {
    @Binding var text: String  // 提示文本绑定（空串=隐藏）

    var body: some View {
        Group {
            if !text.isEmpty {                                     // 非空才渲染
                Text(text)                                         // 提示文本
                    .font(.system(size: 13)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)                     // 内边距
                    .background(Capsule().fill(Color.black.opacity(0.82)))               // 黑色胶囊底
                    .overlay(Capsule().stroke(T.stroke, lineWidth: 1))                   // 描边
                    .padding(.bottom, 46)                                                // 底部悬空
                    .transition(.move(edge: .bottom).combined(with: .opacity))           // 底部滑入+淡入
                    .task(id: text) {                              // 文本变化即重开计时
                        try? await Task.sleep(nanoseconds: 2_400_000_000)  // 睡 2.4s
                        text = ""                                  // 自动消失
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)  // 显隐过渡动画
    }
}

extension View {
    /// Snackbar 便捷修饰器：任意视图底部挂提示条
    func snackbar(_ text: Binding<String>) -> some View {
        overlay(alignment: .bottom) { SnackbarHost(text: text) }  // 底部覆盖
    }
}
