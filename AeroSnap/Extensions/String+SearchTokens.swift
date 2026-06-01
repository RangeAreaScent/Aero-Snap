import Foundation

extension String {
    /// Aero-flavored tokenizer for free-text search.
    ///
    /// Splits on:
    ///   • whitespace
    ///   • `-` and `_`
    ///   • letter↔digit boundary, but ONLY when the alpha side is ≥ 3 chars
    ///     (preserves model designators like `A320`, `B737`, `CF6` while
    ///      breaking up no-space typos like `cessna172`).
    ///
    /// Examples:
    ///   `"cessna172"`         → `["cessna", "172"]`
    ///   `"Boeing 737-800"`    → `["Boeing", "737", "800"]`
    ///   `"A320"`              → `["A320"]`           (kept whole)
    ///   `"ATR42"`             → `["ATR", "42"]`
    ///   `"AC 43.13-1B"`       → `["AC", "43.13", "1B"]`
    ///
    /// Empty tokens are filtered. The result feeds an AND-style SQL
    /// query: every token must appear in at least one indexable column.
    func searchTokens() -> [String] {
        var s = self
        s = s.replacingOccurrences(
            of: #"([A-Za-z]{3,})(\d)"#,
            with: "$1 $2",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: #"(\d)([A-Za-z]{3,})"#,
            with: "$1 $2",
            options: .regularExpression
        )
        return s
            .components(separatedBy: CharacterSet(charactersIn: " -_\t\n"))
            .filter { !$0.isEmpty }
    }
}
