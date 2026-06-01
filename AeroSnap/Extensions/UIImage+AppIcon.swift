import UIKit

extension UIImage {
    /// The installed app icon as a `UIImage`.
    ///
    /// iOS deliberately hides the `AppIcon` asset from `UIImage(named:)` —
    /// it's owned by the system, not the asset catalog's normal lookup.
    /// To show the real app icon inside the app (onboarding hero, About
    /// hero, etc.), we read the primary icon's filename out of
    /// `Info.plist`'s `CFBundleIcons` and load that PNG by name. The last
    /// entry in `CFBundleIconFiles` is the largest variant baked into the
    /// bundle, which is what we want at 88–96pt display size.
    static var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let last = files.last
        else {
            return nil
        }
        return UIImage(named: last)
    }
}
