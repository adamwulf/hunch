@testable import hunch
import XCTest
import YouTubeTranscriptKit

final class YouTubeRateLimiterTests: XCTestCase {
    private let banURL = URL(string: "https://www.google.com/sorry/index")

    /// A stand in for the IP ban: the google.com/sorry wall answers 200, not 429.
    private var banned: YouTubeTranscriptKit.TranscriptError {
        return .rateLimited(statusCode: 200, url: banURL)
    }

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
        XCTAssertFalse(limiter.hasGivenUp)
    }

    func testOtherTranscriptErrorsPassStraightThrough() async throws {
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
        XCTAssertFalse(limiter.hasGivenUp)
    }

    /// Errors that are not TranscriptError at all leave by a different path, unwinding past the
    /// typed catch entirely. ActivityCommand relies on those reaching its fall back to cached data.
    func testNonTranscriptErrorsPropagateUnwrapped() async throws {
        let limiter = fastLimiter()
        let counter = CallCounter()

        do {
            _ = try await limiter.withBackoff { () -> String in
                counter.count += 1
                throw URLError(.timedOut)
            }
            XCTFail("expected the URLError to propagate")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut, "the error should arrive unwrapped, not boxed")
        }

        XCTAssertEqual(counter.count, 1, "a network error should not be retried by the limiter")
        XCTAssertFalse(limiter.hasGivenUp)
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
        } catch let exhausted as YouTubeRateLimiter.RateLimitExhausted {
            XCTAssertEqual(exhausted.waited, 0.02, accuracy: 0.001, "should report both rungs it slept")
            XCTAssertEqual(exhausted.url, banURL, "should report where YouTube redirected us")
            XCTAssertEqual(exhausted.errorDescription?.contains("still rate limiting after"), true)
        }

        // One attempt per rung, plus the initial attempt that tripped the first rung
        XCTAssertEqual(counter.count, 3)
        XCTAssertTrue(limiter.hasGivenUp)

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
        } catch let exhausted as YouTubeRateLimiter.RateLimitExhausted {
            XCTAssertEqual(exhausted.waited, 0.02, accuracy: 0.001, "the success should have zeroed the clock")
        }

        XCTAssertEqual(counter.count, 5, "2 calls to succeed, then 3 more to exhaust a reset ladder")
    }

    /// The export commands cannot afford the backfill ladder, so they give up at the first ban.
    func testSkipTheRestGivesUpOnTheFirstBanWithoutSleeping() async throws {
        let limiter = fastLimiter(rungs: 6)
        let counter = CallCounter()

        do {
            _ = try await limiter.withBackoff(onBan: .skipTheRest) { () -> String in
                counter.count += 1
                throw self.banned
            }
            XCTFail("expected the first ban to end it")
        } catch let exhausted as YouTubeRateLimiter.RateLimitExhausted {
            XCTAssertEqual(exhausted.waited, 0, "should not have slept at all")
            XCTAssertEqual(exhausted.url, banURL)
            XCTAssertEqual(exhausted.errorDescription?.contains("rate limiting this IP"), true,
                           "the message should not claim a backoff that never happened")
        }

        XCTAssertEqual(counter.count, 1, "one banned response is proof enough, probing again deepens the ban")
        XCTAssertTrue(limiter.hasGivenUp)
    }

    func testGivingUpDescribesItselfWithoutAURL() throws {
        let exhausted = YouTubeRateLimiter.RateLimitExhausted(waited: 0, url: nil)

        let description = try XCTUnwrap(exhausted.errorDescription)
        XCTAssertTrue(description.contains("rate limiting this IP"))
        XCTAssertFalse(description.contains("redirected to"), "no URL means no redirect clause")
    }
}
