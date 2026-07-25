import Foundation
import YouTubeTranscriptKit

/// Handles YouTube rate limits on behalf of every YouTube fetch in a run.
///
/// YouTube throttles by IP address, so a rate limit tripped while fetching one video applies to
/// every other request too. Routing all fetches through a single shared limiter means one backoff
/// ladder covers the whole run instead of each call site rediscovering the ban on its own.
///
/// Not thread safe, and it does not need to be: every call site runs sequentially on the single
/// task of one command, and ArgumentParser runs one command per process. If YouTube fetches ever
/// do go concurrent, the fix is not an actor but a shared deadline that callers check before
/// issuing a request. An actor would make the state access safe while still letting two callers
/// each burn a rung on the same ban.
final class YouTubeRateLimiter {
    static let shared = YouTubeRateLimiter()

    /// What a caller wants to happen when YouTube turns out to be banning us.
    enum BanPolicy {
        /// Climb the ladder, sleeping between attempts, because outlasting the ban is the point.
        /// Used by `hunch activity`, which exists to fetch YouTube data and has hours to spend.
        case waitItOut

        /// Give up on YouTube for the rest of the run at the first sign of a ban, without sleeping.
        /// Used by the export commands, whose real job is Notion. A transcript is a bonus there,
        /// and nobody running an export wants it to sit for hours waiting on YouTube.
        case skipTheRest
    }

    /// Thrown once the limiter has given up on YouTube for the rest of this run.
    struct RateLimitExhausted: LocalizedError {
        /// How long we slept before giving up, zero when the caller chose not to wait at all.
        let waited: TimeInterval
        let url: URL?

        var errorDescription: String? {
            var message = waited > 0
                ? "YouTube is still rate limiting after \(RateLimitBackoff.describe(waited)) of backoff"
                : "YouTube is rate limiting this IP"
            if let url = url {
                message += " (redirected to \(url.absoluteString))"
            }
            return message + ". Giving up on YouTube for this run, re-run later to pick up where this left off."
        }
    }

    private var backoff: RateLimitBackoff
    private var waited: TimeInterval = 0
    private var exhausted: RateLimitExhausted?

    init(backoff: RateLimitBackoff = RateLimitBackoff()) {
        self.backoff = backoff
    }

    /// True once the limiter has given up, so callers can skip work they already know will fail.
    var hasGivenUp: Bool {
        return exhausted != nil
    }

    /// Runs `operation`, handling a YouTube ban according to `onBan`.
    ///
    /// Only `TranscriptError.rateLimited` counts as a ban. Every other error passes straight
    /// through untouched, so a video with captions disabled still costs nothing. Once the limiter
    /// gives up it stays given up for the rest of the run and later calls fail immediately without
    /// touching the network, so a banned run stops talking to YouTube rather than dropping back to
    /// full cadence.
    func withBackoff<T>(onBan: BanPolicy, _ operation: () async throws -> T) async throws -> T {
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

                switch onBan {
                case .skipTheRest:
                    // One banned response already proves the whole IP is banned, so a caller that
                    // will not wait gains nothing by probing again and would only deepen the ban.
                    throw giveUp(waited: 0, url: url)
                case .waitItOut:
                    guard let delay = backoff.recordFailure() else {
                        throw giveUp(waited: waited, url: url)
                    }

                    report(statusCode: statusCode, url: url, delay: delay)
                    try await Task.sleep(for: .seconds(delay))
                    waited += delay
                }
            }
        }
    }

    /// Latches the limiter so nothing else in this run tries YouTube again.
    private func giveUp(waited: TimeInterval, url: URL?) -> RateLimitExhausted {
        let failure = RateLimitExhausted(waited: waited, url: url)
        exhausted = failure
        return failure
    }

    private func report(statusCode: Int, url: URL?, delay: TimeInterval) {
        let formatter = DateFormatter()
        // A bare clock time is ambiguous on the long rungs, which are exactly the ones someone
        // reads hours later, so name the day too once a wait reaches 4h
        formatter.dateStyle = delay >= 4 * 60 * 60 ? .short : .none
        formatter.timeStyle = .short
        let resumesAt = formatter.string(from: Date().addingTimeInterval(delay))
        let location = url.map { " at \($0.absoluteString)" } ?? ""

        print("YouTube rate limited (HTTP \(statusCode))\(location)")
        print("  backing off for \(RateLimitBackoff.describe(delay)), resuming around \(resumesAt) "
              + "[\(backoff.failureCount) of \(backoff.rungCount)]")
    }
}
