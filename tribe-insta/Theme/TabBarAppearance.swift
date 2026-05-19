import SwiftUI
import UIKit

/// IG-style chrome for navigation bars. Main app tabs use `InstaBottomTabBar`
/// instead of SwiftUI `TabView` so iOS 26's floating Liquid Glass tab bar
/// never appears. UIKit tab bar appearance is still configured for any
/// nested `TabView` (e.g. post carousels).
enum TabBarAppearance {
    static func apply() {
        configureTabBar()
        configureNavBar()
    }

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.35)

        configureItemAppearance(appearance.stackedLayoutAppearance)
        configureItemAppearance(appearance.inlineLayoutAppearance)
        configureItemAppearance(appearance.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = false
        tabBar.tintColor = UIColor.label
        tabBar.unselectedItemTintColor = UIColor.secondaryLabel
    }

    private static func configureNavBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.35)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        let nav = UINavigationBar.appearance()
        nav.standardAppearance = appearance
        nav.compactAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.compactScrollEdgeAppearance = appearance
        nav.isTranslucent = false
        nav.tintColor = UIColor.label
    }

    private static func configureItemAppearance(_ item: UITabBarItemAppearance) {
        let normal = [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel]
        let selected = [NSAttributedString.Key.foregroundColor: UIColor.label]
        item.normal.iconColor = .secondaryLabel
        item.selected.iconColor = .label
        item.normal.titleTextAttributes = normal
        item.selected.titleTextAttributes = selected
    }
}

extension View {
    /// Pin the nav bar to an opaque system-background fill. iOS 26's
    /// SwiftUI nav bar ignores the UIKit `UINavigationBar.appearance()`
    /// proxy set up above and falls back to a floating Liquid Glass
    /// capsule (renders as a dark pill over the toolbar items). Apply
    /// this on every NavigationStack root that shows a system toolbar.
    func opaqueNavBar() -> some View {
        toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
    }
}
