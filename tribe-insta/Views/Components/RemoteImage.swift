import SwiftUI

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(ProgressView().controlSize(.small))
        }
        .accessibilityHidden(true)
    }
}

private struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loaded: UIImage?
    @State private var failed = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        if let url, let cached = ImageCache.shared.image(for: url) {
            _loaded = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let img = loaded {
                content(Image(uiImage: img))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    @MainActor
    private func load() async {
        guard let url else {
            loaded = nil
            failed = false
            return
        }
        if let cached = ImageCache.shared.image(for: url) {
            loaded = cached
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.store(image, for: url)
                loaded = image
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}
