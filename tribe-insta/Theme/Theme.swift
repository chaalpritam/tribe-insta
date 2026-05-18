import SwiftUI

/// Semantic design tokens aligned with Apple Human Interface Guidelines.
enum Theme {
    static let primary = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    static let surface = Color(.secondarySystemGroupedBackground)
    static let pageBackground = Color(.systemGroupedBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)

    static let cardCornerRadius: CGFloat = 12
    static let sheetCornerRadius: CGFloat = 20

    static let onboardingBackground = Color(.systemGroupedBackground)
}
