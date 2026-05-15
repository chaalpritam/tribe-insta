import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

/// Compose sheet with three modes: Post (photo carousel), Story
/// (single image, 24h auto-expire), Reel (single video).
///
/// Pipeline:
/// - Post:   1–10 images → JPEG re-encode → uploadMedia per image →
///           publishPhotoPost(embeds: ["media:<hash>", ...]).
/// - Story:  1 image → JPEG re-encode → publishStory(mediaHash:,
///           caption:, music:). Hub stamps 24h expires_at.
/// - Reel:   1 video → uploadMedia (video/mp4) → publishReel(
///           videoEmbed: "media:<hash>", audioTitle:, caption:).
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var service: TribeService

    @State private var mode: Mode = .post
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photoLoadeds: [LoadedImage] = []
    @State private var loadedVideo: LoadedVideo? = nil
    @State private var caption: String = ""
    @State private var audioTitle: String = ""
    @State private var music: String = ""
    @State private var isLoading: Bool = false
    @State private var isPublishing: Bool = false
    @State private var errorMessage: String?

    private static let maxImages = 10
    private static let hubImageCap = 5 * 1024 * 1024 // 5 MB
    private static let hubVideoCap = 100 * 1024 * 1024 // 100 MB

    enum Mode: String, CaseIterable, Hashable {
        case post = "Post"
        case story = "Story"
        case reel = "Reel"
    }

    struct LoadedImage: Identifiable {
        let id = UUID()
        let preview: UIImage
        let jpegData: Data
    }

    struct LoadedVideo {
        let url: URL
        let data: Data
        let contentType: String
        /// First-frame thumbnail extracted by AVAssetImageGenerator.
        /// nil when extraction failed (the picker handed back bytes
        /// AVKit couldn't decode — should never happen for video/mp4
        /// or video/quicktime which is what the picker filters to).
        let thumbnail: UIImage?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modePicker
                    mediaSection
                    captionField
                    if mode == .story {
                        musicField
                    } else if mode == .reel {
                        audioTitleField
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New " + mode.rawValue.lowercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await share() }
                    } label: {
                        if isPublishing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Share").fontWeight(.semibold)
                        }
                    }
                    .disabled(!canShare)
                }
            }
        }
        .onChange(of: mode) { _, _ in resetSelection() }
        .onChange(of: pickerItems) { _, newValue in
            Task { await loadPickerItems(newValue) }
        }
    }

    // MARK: Sections

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var mediaSection: some View {
        switch mode {
        case .post:
            if photoLoadeds.isEmpty { emptyPhotoPicker } else { selectedImagesStrip }
        case .story:
            if photoLoadeds.isEmpty { emptyPhotoPicker } else { storyPreview }
        case .reel:
            if loadedVideo == nil { emptyVideoPicker } else { videoPreview }
        }
    }

    private var emptyPhotoPicker: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: mode == .story ? 1 : Self.maxImages,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            placeholder(
                icon: "photo.on.rectangle.angled",
                title: "Tap to choose " + (mode == .story ? "a photo" : "photos"),
                subtitle: mode == .story ? nil : "Up to \(Self.maxImages)"
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyVideoPicker: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: 1,
            selectionBehavior: .ordered,
            matching: .videos
        ) {
            placeholder(
                icon: "video.fill",
                title: "Tap to choose a video",
                subtitle: "Up to 100 MB"
            )
        }
        .buttonStyle(.plain)
    }

    private func placeholder(icon: String, title: String, subtitle: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.gray.opacity(0.15), .gray.opacity(0.3)],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: icon).font(.largeTitle)
                    Text(title)
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .foregroundStyle(.primary)
    }

    private var selectedImagesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photoLoadeds) { image in
                        photoThumbnail(for: image)
                    }
                    addMoreButton
                }
                .padding(.vertical, 2)
            }
            Text("\(photoLoadeds.count) of \(Self.maxImages) photos")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var storyPreview: some View {
        ZStack(alignment: .topTrailing) {
            if let image = photoLoadeds.first {
                Image(uiImage: image.preview)
                    .resizable()
                    .aspectRatio(9.0/16.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                photoLoadeds = []
                pickerItems = []
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .padding(8)
        }
    }

    private var videoPreview: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumb = loadedVideo?.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [.black, .gray.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
            .aspectRatio(9.0/16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.4)],
                    startPoint: .center, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .overlay(
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.callout).foregroundStyle(.white)
                        if let video = loadedVideo {
                            Text("\((Double(video.data.count) / 1_048_576).rounded(toPlaces: 1)) MB · \(video.contentType)")
                                .font(.caption).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            )

            Button {
                loadedVideo = nil
                pickerItems = []
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .padding(8)
        }
    }

    private func photoThumbnail(for image: LoadedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image.preview)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                if let idx = photoLoadeds.firstIndex(where: { $0.id == image.id }) {
                    photoLoadeds.remove(at: idx)
                    if idx < pickerItems.count {
                        pickerItems.remove(at: idx)
                    }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .padding(4)
        }
    }

    private var addMoreButton: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: Self.maxImages,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                )
        }
        .buttonStyle(.plain)
        .disabled(photoLoadeds.count >= Self.maxImages)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Caption").font(.caption).foregroundStyle(.secondary)
            TextField(captionPlaceholder, text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var captionPlaceholder: String {
        switch mode {
        case .post: return "Write a caption…"
        case .story: return "Add a story caption…"
        case .reel:  return "Write a reel caption…"
        }
    }

    private var musicField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Music").font(.caption).foregroundStyle(.secondary)
            TextField("Optional · e.g. \"Track · Artist\"", text: $music)
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var audioTitleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio title").font(.caption).foregroundStyle(.secondary)
            TextField("Optional · e.g. \"Original audio\"", text: $audioTitle)
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Derived

    private var canShare: Bool {
        guard !isPublishing, !isLoading else { return false }
        switch mode {
        case .post, .story: return !photoLoadeds.isEmpty
        case .reel: return loadedVideo != nil
        }
    }

    // MARK: Actions

    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            photoLoadeds = []
            loadedVideo = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        switch mode {
        case .reel:
            guard let first = items.first,
                  let data = try? await first.loadTransferable(type: Data.self)
            else {
                loadedVideo = nil
                return
            }
            guard data.count <= Self.hubVideoCap else {
                errorMessage = "Video exceeds 100 MB cap."
                loadedVideo = nil
                return
            }
            let resolvedContentType = contentType(for: first) ?? "video/mp4"
            let thumbnail = await Self.extractFirstFrame(
                data: data,
                contentType: resolvedContentType
            )
            loadedVideo = LoadedVideo(
                url: URL(fileURLWithPath: "(picker)"),
                data: data,
                contentType: resolvedContentType,
                thumbnail: thumbnail
            )
            photoLoadeds = []
        case .post, .story:
            var loaded: [LoadedImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data)
                else { continue }
                guard let jpeg = Self.encodeJPEG(uiImage) else { continue }
                loaded.append(LoadedImage(preview: uiImage, jpegData: jpeg))
            }
            // Story is single-image; clamp.
            photoLoadeds = mode == .story ? Array(loaded.prefix(1)) : loaded
            loadedVideo = nil
        }
    }

    @MainActor
    private func share() async {
        errorMessage = nil
        isPublishing = true
        defer { isPublishing = false }
        do {
            switch mode {
            case .post:
                guard !photoLoadeds.isEmpty else { return }
                _ = try await service.publishPhotoPost(
                    images: photoLoadeds.map { ($0.jpegData, "image/jpeg") },
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            case .story:
                guard let image = photoLoadeds.first else { return }
                _ = try await service.publishStory(
                    image: (image.jpegData, "image/jpeg"),
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    music: music.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            case .reel:
                guard let video = loadedVideo else { return }
                _ = try await service.publishReel(
                    video: (video.data, video.contentType),
                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                    audioTitle: audioTitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    location: nil
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetSelection() {
        photoLoadeds = []
        loadedVideo = nil
        pickerItems = []
        errorMessage = nil
    }

    private func contentType(for item: PhotosPickerItem) -> String? {
        let identifier = item.supportedContentTypes.first?.identifier
        // PhotosUI doesn't always give us a content type — fall back
        // to mp4 since QuickTime gets re-encoded by AVKit's exporters
        // on most modern iPhones.
        switch identifier {
        case "public.mpeg-4": return "video/mp4"
        case "com.apple.quicktime-movie": return "video/quicktime"
        default: return nil
        }
    }

    // MARK: Video thumbnail

    /// Write the picker's raw bytes to a temp file, load as AVURLAsset,
    /// and pull a frame at ~0.1s in. Doing this off-actor on a detached
    /// Task so it doesn't block the main run loop during the picker's
    /// dismissal animation. Returns nil if the bytes don't decode.
    private static func extractFirstFrame(
        data: Data,
        contentType: String
    ) async -> UIImage? {
        let ext = contentType == "video/quicktime" ? "mov" : "mp4"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-\(UUID().uuidString).\(ext)")
        guard (try? data.write(to: tmp)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: tmp) }

        return await withCheckedContinuation { cont in
            let asset = AVURLAsset(url: tmp)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            // First playable frame, not the very first sample at 0:
            // some encoders open with black or sync padding.
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            gen.generateCGImageAsynchronously(for: time) { cg, _, _ in
                if let cg {
                    cont.resume(returning: UIImage(cgImage: cg))
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    // MARK: Encoding

    private static func encodeJPEG(_ image: UIImage) -> Data? {
        for quality in [0.85, 0.7, 0.5] as [CGFloat] {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= hubImageCap {
                return data
            }
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

#Preview {
    CreatePostView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
