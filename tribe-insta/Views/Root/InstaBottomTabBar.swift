import SwiftUI

/// Fixed bottom tab bar matching Instagram: Home, Search, Create (+),
/// Reels, Profile. DMs live on the feed top bar.
struct InstaBottomTabBar: View {
    @Binding var selection: RootView.Tab
    let profileAvatarURL: URL?
    let onCreateTap: () -> Void

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
                createButton
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

    private var createButton: some View {
        Button(action: onCreateTap) {
            Image(systemName: "plus.square")
                .font(.system(size: 26))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create")
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
        selectedIcon: String
    ) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            Image(systemName: isSelected ? selectedIcon : icon)
                .font(.system(size: 26))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
