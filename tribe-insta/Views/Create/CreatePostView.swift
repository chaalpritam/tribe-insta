import SwiftUI
import PhotosUI
import UIKit

/// Compose-post sheet. Pick 1–10 photos, write a caption, share.
///
/// Pipeline:
/// 1. PhotosPicker hands back `PhotosPickerItem`s.
/// 2. We load each as raw bytes, decode to UIImage, re-encode as JPEG
///    at quality 0.85. Hub caps uploads at 5 MB; we step quality down
///    if the encoded payload comes back larger than that.
/// 3. TribeService.publishPhotoPost uploads each blob to /v1/upload,
///    collects the hashes, and submits a TWEET_ADD envelope with
///    `embeds = ["media:<hash>", ...]`.
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var service: TribeService

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [LoadedImage] = []
    @State private var caption: String = ""
    @State private var isLoadingImages: Bool = false
    @State private var isPublishing: Bool = false
    @State private var errorMessage: String?

    private static let maxImages = 10
    private static let hubUploadCap = 5 * 1024 * 1024 // 5 MB

    struct LoadedImage: Identifiable {
        let id = UUID()
        let preview: UIImage
        let jpegData: Data
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if images.isEmpty {
                        emptyPicker
                    } else {
                        selectedImagesStrip
                    }
                    captionField
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    optionsList
                }
                .padding(16)
            }
            .navigationTitle("New post")
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
        .onChange(of: pickerItems) { _, newValue in
            Task { await loadPickerItems(newValue) }
        }
    }

    // MARK: Sections

    private var emptyPicker: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: Self.maxImages,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.gray.opacity(0.15), .gray.opacity(0.3)],
                                         startPoint: .top, endPoint: .bottom))
                VStack(spacing: 10) {
                    if isLoadingImages {
                        ProgressView()
                    } else {
                        Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                        Text("Tap to choose photos")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Up to \(Self.maxImages)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var selectedImagesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(images) { image in
                        thumbnail(for: image)
                    }
                    addMoreButton
                }
                .padding(.vertical, 2)
            }
            Text("\(images.count) of \(Self.maxImages) photos")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func thumbnail(for image: LoadedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image.preview)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                if let idx = images.firstIndex(where: { $0.id == image.id }) {
                    images.remove(at: idx)
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
        .disabled(images.count >= Self.maxImages)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Caption").font(.caption).foregroundStyle(.secondary)
            TextField("Write a caption…", text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Decorative for Phase 2 — Tag people / Add location / Add music
    /// / Also share to don't have envelope shapes yet (location lands
    /// in Phase 3's hub schema bump). Left visible so the surface
    /// previews what the eventual create flow looks like.
    private var optionsList: some View {
        VStack(spacing: 0) {
            row(icon: "person.crop.rectangle", title: "Tag people")
            Divider().padding(.leading, 44)
            row(icon: "mappin.and.ellipse", title: "Add location")
            Divider().padding(.leading, 44)
            row(icon: "music.note", title: "Add music")
            Divider().padding(.leading, 44)
            row(icon: "square.and.arrow.up", title: "Also share to…")
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .opacity(0.5)
        .overlay(alignment: .topTrailing) {
            Text("Phase 3")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.bar, in: Capsule())
                .padding(8)
        }
    }

    private func row(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .foregroundStyle(.primary)
    }

    // MARK: Derived

    private var canShare: Bool {
        !images.isEmpty && !isPublishing && !isLoadingImages
    }

    // MARK: Actions

    /// Resolve every PhotosPickerItem the user picked into a
    /// JPEG-encoded payload + UIImage preview. The picker may hand
    /// us HEIC, PNG, or already-JPEG bytes; re-encoding as JPEG
    /// ensures (a) the hub accepts the MIME type (its uploader is
    /// the four common image types — HEIC isn't on the list) and
    /// (b) we can step quality down to stay under the 5 MB cap.
    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            images = []
            return
        }
        isLoadingImages = true
        defer { isLoadingImages = false }
        var loaded: [LoadedImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else { continue }
            guard let jpeg = Self.encodeJPEG(uiImage) else { continue }
            loaded.append(LoadedImage(preview: uiImage, jpegData: jpeg))
        }
        images = loaded
    }

    @MainActor
    private func share() async {
        guard !images.isEmpty else { return }
        isPublishing = true
        errorMessage = nil
        defer { isPublishing = false }
        do {
            let payload = images.map { (data: $0.jpegData, contentType: "image/jpeg") }
            _ = try await service.publishPhotoPost(
                images: payload,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Encoding

    /// Re-encode at JPEG quality 0.85 first; if the encoded blob is
    /// over the hub's 5 MB cap, step down to 0.7, then 0.5. Below that
    /// the image isn't worth posting — bail with nil and let the
    /// caller skip it.
    private static func encodeJPEG(_ image: UIImage) -> Data? {
        for quality in [0.85, 0.7, 0.5] as [CGFloat] {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= hubUploadCap {
                return data
            }
        }
        return nil
    }
}

#Preview {
    CreatePostView()
        .environmentObject(AppState())
        .environmentObject(TribeService(state: AppState()))
}
