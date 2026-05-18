import SwiftUI

/// Profile tab bar icon: user avatar when available, otherwise a person glyph.
struct ProfileTabIcon: View {
    let avatarURL: URL?
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let avatarURL {
                RemoteImage(url: avatarURL)
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
            } else {
                Image(systemName: isSelected ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            Circle()
                .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                .frame(width: 30, height: 30)
        }
        .frame(width: 30, height: 30)
        .accessibilityLabel("Profile")
    }
}
