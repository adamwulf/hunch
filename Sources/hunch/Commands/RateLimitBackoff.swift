import Foundation

/// Tracks how long to wait between retries after YouTube rate limits a request.
///
/// YouTube throttles bulk fetching at the IP level for long stretches at a time, so the delays
/// step up in minutes and hours rather than seconds. Each rate limited attempt advances one rung
/// of the ladder, and a successful request resets back to the bottom.
struct RateLimitBackoff {
    /// Delays applied to successive rate limited attempts: 5m, 15m, 30m, 1h, 4h, 12h.
    static let defaultDelays: [TimeInterval] = [
        5 * 60,
        15 * 60,
        30 * 60,
        60 * 60,
        4 * 60 * 60,
        12 * 60 * 60
    ]

    private let delays: [TimeInterval]

    /// Number of rate limited attempts recorded since the last reset.
    private(set) var failureCount = 0

    init(delays: [TimeInterval] = RateLimitBackoff.defaultDelays) {
        assert(!delays.isEmpty, "a backoff ladder needs at least one delay")
        self.delays = delays
    }

    /// How many rungs the ladder has in total.
    var rungCount: Int {
        return delays.count
    }

    /// How long the next rate limited attempt will wait, or nil once every rung has been used.
    var nextDelay: TimeInterval? {
        guard failureCount < delays.count else { return nil }
        return delays[failureCount]
    }

    /// Records a rate limited attempt and returns how long to wait before retrying, or nil when
    /// every delay in the ladder has already been used.
    mutating func recordFailure() -> TimeInterval? {
        guard let delay = nextDelay else { return nil }
        failureCount += 1
        return delay
    }

    /// Steps back to the first delay, called after a request succeeds.
    mutating func reset() {
        failureCount = 0
    }

    /// Human readable form of a delay, e.g. "5m", "1h", "1h 30m".
    static func describe(_ delay: TimeInterval) -> String {
        let totalMinutes = Int((delay / 60).rounded())
        guard totalMinutes >= 60 else { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
