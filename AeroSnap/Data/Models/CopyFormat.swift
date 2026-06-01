import Foundation

/// User-selectable copy formats. Row-level copy (swipe action, default
/// list copy) uses `short` or `withTitle`. The detail screen also offers
/// `fullDetail` as an explicit menu item.
enum CopyFormat: String, CaseIterable, Identifiable, Sendable {
    case short          // "AD 2024-10-18" / "14 CFR § 43.13" / "TCDS 3A12"
    case withTitle      // identifier + " — " + title/heading/manufacturer
    case fullDetail     // multi-line full content (detail-only)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short:       return "Identifier only"
        case .withTitle:   return "Identifier + title"
        case .fullDetail:  return "Full detail"
        }
    }

    /// Row-level copy actions only offer the two short formats; full
    /// detail is reserved for an explicit detail-screen action.
    var isRowFormat: Bool {
        switch self {
        case .short, .withTitle: return true
        case .fullDetail:        return false
        }
    }
}
