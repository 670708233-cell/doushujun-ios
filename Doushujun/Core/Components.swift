import SwiftUI

// MARK: - 网络图片（列表封面/头像）

struct NetImage: View {
    let url: String?
    var width: CGFloat? = nil
    var height: CGFloat? = nil

    @State private var img: UIImage? = nil

    private static let cache = NSCache<NSString, UIImage>()

    init(url: String?, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.url = url
        self.width = width
        self.height = height
    }

    /// 正方形便捷构造（头像等）
    init(url: String?, size: CGFloat) {
        self.init(url: url, width: size, height: size)
    }

    var body: some View {
        Group {
            if let img = img {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    T.cardHi
                    ProgressView().scaleEffect(0.7).tint(T.textSub)
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear { load() }
    }

    private func load() {
        guard let u = url, !u.isEmpty, img == nil else { return }
        if let hit = Self.cache.object(forKey: u as NSString) {
            img = hit
            return
        }
        guard let req = URL(string: u) else { return }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let im = UIImage(data: data) else { return }
            Self.cache.setObject(im, forKey: u as NSString)
            DispatchQueue.main.async {
                // 仅当仍展示同一 URL 时更新（复用场景防串图）
                if url == u { img = im }
            }
        }.resume()
    }
}

// MARK: - 公告条（bus.announcement 有内容时显示）

struct AnnouncementBar: View {
    @ObservedObject private var bus = SessionBus.shared

    var body: some View {
        if let a = bus.announcement {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12)).foregroundColor(T.warn)
                Text(a.content)
                    .font(.system(size: 12)).foregroundColor(T.textSub)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(T.warn.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(T.warn.opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - 渐变横幅（页头标题区）

struct GradientBanner: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(T.grad)
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold)).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(T.textMain)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11)).foregroundColor(T.textSub).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [T.primary.opacity(0.10), T.secondary.opacity(0.10)],
                                     startPoint: .leading, endPoint: .trailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(T.stroke, lineWidth: 1))
    }
}

// MARK: - Snackbar（.snackbar($text)：非空即显示，2.4s 自动消失）

struct SnackbarHost: View {
    @Binding var text: String

    var body: some View {
        Group {
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 13)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.82)))
                    .overlay(Capsule().stroke(T.stroke, lineWidth: 1))
                    .padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: text) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        text = ""
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)
    }
}

extension View {
    func snackbar(_ text: Binding<String>) -> some View {
        overlay(alignment: .bottom) { SnackbarHost(text: text) }
    }
}
