import Foundation

enum Formatters {
    static func compactCount(_ value: Int) -> String {
        let n = Double(value)
        switch n {
        case 1_000_000...:
            return trim(n / 1_000_000) + "M"
        case 1_000...:
            return trim(n / 1_000) + "K"
        default:
            return "\(value)"
        }
    }

    private static func trim(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded))"
            : String(format: "%.1f", rounded)
    }

    static func shortRelative(_ date: Date, reference: Date = Date()) -> String {
        let seconds = Int(reference.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3_600)h"
        case ..<604_800: return "\(seconds / 86_400)d"
        default: return "\(seconds / 604_800)w"
        }
    }
}
