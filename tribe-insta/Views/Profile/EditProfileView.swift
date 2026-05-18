import SwiftUI
import PhotosUI

/// Edit display name, bio, and avatar for the signed-in user.
struct EditProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var service: TribeService
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarPreview: UIImage?
    @State private var avatarURL: URL?
    @State private var publishing = false
    @State private var error: String?

    private let maxLength = 500

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        if let avatarPreview {
                            Image(uiImage: avatarPreview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                        } else {
                            AvatarView(url: avatarURL, size: 72)
                        }
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Text("Change photo")
                        }
                    }
                }

                Section("Public profile") {
                    TextField("Display name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.error)
                            .font(.footnote)
                    }
                }

                Section {
                    Button { Task { await publish() } } label: {
                        HStack {
                            if publishing { ProgressView() }
                            Text(publishing ? "Saving…" : "Save changes")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(publishing)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
            .onChange(of: avatarItem) { _, item in
                Task { await loadAvatarPreview(item) }
            }
        }
    }

    @MainActor
    private func load() async {
        guard let tid = state.myTID,
              let hubUser = try? await state.api.fetchUser(tid)
        else { return }
        displayName = hubUser.profile?.displayName ?? ""
        bio = hubUser.profile?.bio ?? ""
        avatarURL = hubUser.profile?.pfpUrl.flatMap { service.api.resolveMediaURL($0) }
    }

    @MainActor
    private func loadAvatarPreview(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        avatarPreview = image
    }

    @MainActor
    private func publish() async {
        publishing = true
        defer { publishing = false }
        error = nil
        do {
            let dn = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if dn.count > maxLength || b.count > maxLength {
                error = "Fields must be under \(maxLength) characters."
                return
            }
            if !dn.isEmpty { try await service.updateProfileField("displayName", value: dn) }
            if !b.isEmpty { try await service.updateProfileField("bio", value: b) }
            if let avatarPreview, let jpeg = avatarPreview.jpegData(compressionQuality: 0.85) {
                try await service.updateAvatar(imageJPEG: jpeg)
            }
            dismiss()
        } catch let err {
            self.error = err.localizedDescription
        }
    }
}
