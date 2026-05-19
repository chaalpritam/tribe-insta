import SwiftUI

/// Fixed bottom tab bar matching Instagram: full-width, opaque, icon-only,
/// no Liquid Glass floating platter. Used instead of SwiftUI `TabView`.
struct InstaBottomTabBar: View {
    @Binding var selection: RootView.Tab
    let unreadDMCount: Int
    let profileAvatarURL: URL?

    private let barHeight: CGFloat = 49

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                tabButton(
                    tab: .feed,
                    label: "Home",
                    icon: "house",
                    selectedIcon: "house.fill"
                )
                tabButton(
                    tab: .search,
                    label: "Search",
                    icon: "magnifyingglass",
                    selectedIcon: "magnifyingglass"
                )
                tabButton(
                    tab: .messages,
                    label: "Messages",
                    icon: "paperplane",
                    selectedIcon: "paperplane.fill",
                    badge: unreadDMCount
                )
                tabButton(
                    tab: .reels,
                    label: "Reels",
                    icon: "play.rectangle",
                    selectedIcon: "play.rectangle.fill"
                )
                profileButton
            }
            .frame(height: barHeight)
        }
        .background {
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var profileButton: some View {
        Button {
            selection = .profile
        } label: {
            ProfileTabIcon(
                avatarURL: profileAvatarURL,
                isSelected: selection == .profile
            )
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(selection == .profile ? .isSelected : [])
    }

    private func tabButton(
        tab: RootView.Tab,
        label: String,
        icon: String,
        selectedIcon: String,
        badge: Int = 0
    ) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 26))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.red, in: Circle())
                        .offset(x: 10, y: -6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
