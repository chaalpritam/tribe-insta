import SwiftUI

/// UGC reporting helper until the hub exposes a formal report envelope.
struct ReportContentSheet: View {
    let postHash: String?
    let authorTID: String?
    let authorUsername: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var reportBody: String {
        var lines = ["Tribe insta content report", ""]
        if let postHash { lines.append("Post hash: \(postHash)") }
        lines.append("Author: @\(authorUsername)")
        if let authorTID { lines.append("TID: \(authorTID)") }
        lines.append("")
        lines.append("Describe the issue:")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reports are reviewed manually. Include the post hash so moderators can find it on the hub.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Details") {
                    if let postHash {
                        LabeledContent("Post", value: postHash)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("Author", value: "@\(authorUsername)")
                    if let authorTID {
                        LabeledContent("TID", value: authorTID)
                    }
                }
                Section {
                    Button {
                        UIPasteboard.general.string = reportBody
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy report details", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    if let url = mailtoURL {
                        Link(destination: url) {
                            Label("Email report", systemImage: "envelope")
                        }
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@tribeprotocol.xyz"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "tribe-insta content report"),
            URLQueryItem(name: "body", value: reportBody),
        ]
        return components.url
    }
}
