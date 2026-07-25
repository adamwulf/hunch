import Foundation
import YouTubeTranscriptKit

/// Waits out YouTube rate limits on behalf of every YouTube fetch in a run.
///
/// YouTube throttles by IP address, so a rate limit tripped while fetching one video applies to
/// every other request too. Routing all fetches through a single shared limiter means one backoff
/// ladder covers the whole run instead of each call site rediscovering the ban on its own.
final class YouTubeRateLimiter {
    static let shared = YouTubeRateLimiter()

    /// Thrown once every rung of the backoff ladder has been used and YouTube is still refusing.
    struct RateLimitExhausted: LocalizedError {
        let waited: TimeInterval
        let url: URL?

        var errorDescription: String? {
            var message = "YouTube is still rate limiting after \(RateLimitBackoff.describe(waited)) of backoff"
            if let url = url {
                message += " (last redirected to \(url.absoluteString))"
            }
            return message + ". Stopping, re-run later to pick up where this left off."
        }
    }

    private var backoff: RateLimitBackoff
    private var waited: TimeInterval = 0
    private var exhausted: RateLimitExhausted?

    init(backoff: RateLimitBackoff = RateLimitBackoff()) {
        self.backoff = backoff
    }

    /// Runs `operation`, sleeping out any YouTube rate limit and retrying until it succeeds or
    /// fails for some other reason.
    ///
    /// Only `TranscriptError.rateLimited` earns a sleep — every other error passes straight
    /// through untouched. Once the ladder is exhausted the limiter stays exhausted for the rest of
    /// the run and later calls fail immediately without touching the network, so a banned run stops
    /// talking to YouTube rather than hammering it at full cadence.
    func withBackoff<T>(_ operation: () async throws -> T) async throws -> T {
        if let exhausted = exhausted {
            throw exhausted
        }

        while true {
            do {
                let result = try await operation()
                backoff.reset()
                waited = 0
                return result
            } catch let error as YouTubeTranscriptKit.TranscriptError {
                // Match the case, never the status code: the google.com/sorry CAPTCHA wall that
                // signals an IP ban answers with 200 because URLSession follows the 302 to it.
                guard case YouTubeTranscriptKit.TranscriptError.rateLimited(let statusCode, let url) = error else {
                    throw error
                }

                guard let delay = backoff.recordFailure() else {
                    let failure = RateLimitExhausted(waited: waited, url: url)
                    exhausted = failure
                    throw failure
                }

                waited += delay
                report(statusCode: statusCode, url: url, delay: delay)
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func report(statusCode: Int, url: URL?, delay: TimeInterval) {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let resumesAt = formatter.string(from: Date().addingTimeInterval(delay))
        let location = url.map { " at \($0.absoluteString)" } ?? ""

        print("YouTube rate limited (HTTP \(statusCode))\(location)")
        print("  backing off for \(RateLimitBackoff.describe(delay)), resuming around \(resumesAt) "
              + "[\(backoff.failureCount) of \(backoff.rungCount)]")
    }
}
