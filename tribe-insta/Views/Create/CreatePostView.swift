import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var caption: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    placeholder

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Caption").font(.caption).foregroundStyle(.secondary)
                        TextField("Write a caption…", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(10)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 10))
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
                    Button("Share") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.gray.opacity(0.15), .gray.opacity(0.3)],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                Text("Tap to choose photos")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

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
    }

    private func row(icon: String, title: String) -> some View {
        Button { } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreatePostView()
}
