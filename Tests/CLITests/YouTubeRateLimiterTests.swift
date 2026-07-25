@testable import hunch
import XCTest
import YouTubeTranscriptKit

final class YouTubeRateLimiterTests: XCTestCase {
    /// A stand in for the IP ban: the google.com/sorry wall answers 200, not 429.
    private let banned = YouTubeTranscriptKit.TranscriptError.rateLimited(
        statusCode: 200,
        url: URL(string: "https://www.google.com/sorry/index")
    )

    /// Milliseconds instead of minutes so the tests do not actually sit out a ban.
    private func fastLimiter(rungs: Int = 2) -> YouTubeRateLimiter {
        return YouTubeRateLimiter(backoff: RateLimitBackoff(delays: Array(repeating: 0.01, count: rungs)))
    }

    private final class CallCounter {
        var count = 0
    }

    func testRateLimitedCallIsRetriedAfterBackingOff() async throws {
        let limiter = fastLimiter()
        let counter = CallCounter()

        let result = try await limiter.withBackoff { () -> String in
            counter.count += 1
            if counter.count == 1 {
                throw self.banned
            }
            return "transcript"
        }

        XCTAssertEqual(result, "transcript")
        XCTAssertEqual(counter.count, 2)
    }

    func testErrorsOtherThanRateLimitedPassStraightThrough() async throws {
        let limiter = fastLimiter()
        let counter = CallCounter()

        do {
            _ = try await limiter.withBackoff { () -> String in
                counter.count += 1
                throw YouTubeTranscriptKit.TranscriptError.noCaptionData
            }
            XCTFail("expected noCaptionData to propagate")
        } catch YouTubeTranscriptKit.TranscriptError.noCaptionData {
            // expected: only a rate limit earns a sleep
        }

        XCTAssertEqual(counter.count, 1, "a non rate limit error should not be retried")
    }

    func testLadderExhaustsThenStaysExhausted() async throws {
        let limiter = fastLimiter(rungs: 2)
        let counter = CallCounter()

        do {
            _ = try await limiter.withBackoff { () -> String in
                counter.count += 1
                throw self.banned
            }
            XCTFail("expected the backoff ladder to run out")
        } catch is YouTubeRateLimiter.RateLimitExhausted {
            // expected once every rung has been used
        }

        // One attempt per rung, plus the initial attempt that tripped the first rung
        XCTAssertEqual(counter.count, 3)

        // Later calls fail immediately instead of hammering YouTube while it is still banning us
        do {
            _ = try await limiter.withBackoff { () -> String in
                counter.count += 1
                return "should not run"
            }
            XCTFail("expected an exhausted limiter to refuse further work")
        } catch is YouTubeRateLimiter.RateLimitExhausted {
            // expected
        }

        XCTAssertEqual(counter.count, 3, "an exhausted limiter should not touch the network again")
    }

    func testSuccessResetsTheLadder() async throws {
        let limiter = fastLimiter(rungs: 2)
        let counter = CallCounter()

        // Trip one rung, then succeed, which should put the ladder back at the bottom
        _ = try await limiter.withBackoff { () -> String in
            counter.count += 1
            if counter.count == 1 {
                throw self.banned
            }
            return "ok"
        }

        // With the ladder reset there are two fresh rungs left, so two more sleeps before it gives up
        do {
            _ = try await limiter.withBackoff { () -> String in
                counter.count += 1
                throw self.banned
            }
            XCTFail("expected the backoff ladder to run out")
        } catch is YouTubeRateLimiter.RateLimitExhausted {
            // expected
        }

        XCTAssertEqual(counter.count, 5, "2 calls to succeed, then 3 more to exhaust a reset ladder")
    }
}
