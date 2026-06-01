import Foundation
import Observation

/// Persistent rolling list of recent search queries. Newest first, FIFO
/// with a fixed cap (default 10). Case-insensitive dedup.
@MainActor
@Observable
final class SearchHistoryManager {
    static let shared = SearchHistoryManager()

    static let maxItems = 10
    private static let storageKey = "search.history"

    private(set) var queries: [String] = []

    private init() {
        if let saved = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            queries = Array(saved.prefix(Self.maxItems))
        }
    }

    /// Insert (or move to front) a query. Empty / whitespace ignored.
    /// Case-insensitive dedup — typing the same query twice doesn't
    /// create two entries even if capitalization differs.
    func record(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Remove existing entry that matches case-insensitively.
        queries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        queries.insert(trimmed, at: 0)
        if queries.count > Self.maxItems {
            queries = Array(queries.prefix(Self.maxItems))
        }
        persist()
    }

    func remove(_ query: String) {
        queries.removeAll { $0 == query }
        persist()
    }

    func clear() {
        queries.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(queries, forKey: Self.storageKey)
    }
}
