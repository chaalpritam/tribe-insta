import SwiftUI
import UIKit

/// IG-style opaque tab bar so icons stay visible over Reels/camera black content.
enum TabBarAppearance {
    static func apply() {
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

    private static func configureItemAppearance(_ item: UITabBarItemAppearance) {
        let normal = [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel]
        let selected = [NSAttributedString.Key.foregroundColor: UIColor.label]
        item.normal.iconColor = .secondaryLabel
        item.selected.iconColor = .label
        item.normal.titleTextAttributes = normal
        item.selected.titleTextAttributes = selected
    }
}
