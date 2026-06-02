import Foundation
import Observation

/// Detects a specific tap-rhythm pattern intended as a hidden trigger —
/// in Aero Snap, it's wired to the AboutView version row to flip the
/// supporter-unlock state (so beta testers and App Store reviewers can
/// audit the premium themes / icons without a sandbox purchase).
///
/// Pattern: 6 taps as 3 pairs of double-taps separated by intentional pauses:
///
///     [tap-tap]      [tap-tap]      [tap-tap]
///      ↑ <0.7s        ↑ 1.0~3.5s    ↑ <0.7s
///                     ↑ 1.0~3.5s
///
/// Gap validation (5 gaps between 6 taps):
///   - gap[0] (between tap 1 & 2): double-tap, 0.05~0.7s
///   - gap[1] (between tap 2 & 3): intentional wait, 1.0~3.5s
///   - gap[2] (between tap 3 & 4): double-tap, 0.05~0.7s
///   - gap[3] (between tap 4 & 5): intentional wait, 1.0~3.5s
///   - gap[4] (between tap 5 & 6): double-tap, 0.05~0.7s
///
/// Early validation: a tap whose preceding gap is out of the expected
/// range for its position resets the sequence and re-anchors as the new
/// "tap 1". Accidental triggering is effectively impossible while a
/// fumbled attempt can be recovered.
///
/// Auto-reset: 5 seconds of inactivity clears the in-progress sequence.
@MainActor
@Observable
final class SecretTapDetector {
    private var tapTimestamps: [Date] = []
    private var resetTask: Task<Void, Never>?

    private let doubleTapRange: ClosedRange<TimeInterval> = 0.05...0.7
    private let waitRange: ClosedRange<TimeInterval> = 1.0...3.5
    private let inactivityResetSeconds: TimeInterval = 5.0
    private let totalTaps = 6

    /// Called when the full 6-tap pattern is recognized. Assign once
    /// (typically in `.onAppear`) and call `registerTap()` from the
    /// tap gesture.
    var onSuccess: () -> Void = {}

    func registerTap() {
        let now = Date()
        tapTimestamps.append(now)
        scheduleInactivityReset()

        if tapTimestamps.count >= 2 {
            let lastIndex = tapTimestamps.count - 1
            let gap = tapTimestamps[lastIndex].timeIntervalSince(tapTimestamps[lastIndex - 1])
            let gapIndex = lastIndex - 1     // 0…4 for 6 taps
            // Even-index gaps (0, 2, 4) are double-taps; odd (1, 3) are waits.
            let expectedRange = gapIndex.isMultiple(of: 2) ? doubleTapRange : waitRange
            if !expectedRange.contains(gap) {
                tapTimestamps = [now]        // re-anchor on this tap
                return
            }
        }

        if tapTimestamps.count == totalTaps {
            let callback = onSuccess
            reset()
            callback()
        }
    }

    private func scheduleInactivityReset() {
        resetTask?.cancel()
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.inactivityResetSeconds ?? 5))
            guard !Task.isCancelled else { return }
            self?.reset()
        }
    }

    private func reset() {
        tapTimestamps.removeAll()
        resetTask?.cancel()
        resetTask = nil
    }
}
