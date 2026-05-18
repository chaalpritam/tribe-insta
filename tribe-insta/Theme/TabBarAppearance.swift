import SwiftUI
import UIKit

/// IG-style chrome: opaque tab bar at the bottom + opaque nav bar at the top,
/// so neither dissolves into the photo content the way iOS 26's Liquid Glass
/// defaults do. Without this, the nav bar items render as floating glass
/// capsules over the feed and the tab bar minimizes to a single dark pill.
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
