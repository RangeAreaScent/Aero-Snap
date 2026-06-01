import UIKit

@MainActor
enum Pasteboard {
    /// Put `text` on the system pasteboard and fire a success haptic.
    /// Returns the same string for caller convenience (toast text, log lines).
    @discardableResult
    static func copy(_ text: String) -> String {
        UIPasteboard.general.string = text
        Haptics.notification(.success)
        return text
    }
}
