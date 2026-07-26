@testable import hunch
import XCTest

final class RateLimitBackoffTests: XCTestCase {
    private let minute: TimeInterval = 60
    private let hour: TimeInterval = 60 * 60

    func testLadderStepsUpFromFiveMinutesToTwelveHours() {
        var backoff = RateLimitBackoff()

        XCTAssertEqual(backoff.recordFailure(), 5 * minute)
        XCTAssertEqual(backoff.recordFailure(), 15 * minute)
        XCTAssertEqual(backoff.recordFailure(), 30 * minute)
        XCTAssertEqual(backoff.recordFailure(), 1 * hour)
        XCTAssertEqual(backoff.recordFailure(), 4 * hour)
        XCTAssertEqual(backoff.recordFailure(), 12 * hour)
    }

    func testLadderExhaustsAfterTheLastRung() {
        var backoff = RateLimitBackoff()

        for _ in 0..<backoff.rungCount {
            XCTAssertNotNil(backoff.recordFailure())
        }

        XCTAssertNil(backoff.nextDelay)
        XCTAssertNil(backoff.recordFailure())
        XCTAssertEqual(backoff.failureCount, backoff.rungCount)
    }

    func testResetReturnsToTheFirstRung() {
        var backoff = RateLimitBackoff()
        _ = backoff.recordFailure()
        _ = backoff.recordFailure()
        XCTAssertEqual(backoff.failureCount, 2)

        backoff.reset()

        XCTAssertEqual(backoff.failureCount, 0)
        XCTAssertEqual(backoff.recordFailure(), 5 * minute)
    }

    func testNextDelayDoesNotAdvanceTheLadder() {
        var backoff = RateLimitBackoff()

        XCTAssertEqual(backoff.nextDelay, 5 * minute)
        XCTAssertEqual(backoff.nextDelay, 5 * minute)
        XCTAssertEqual(backoff.failureCount, 0)
        XCTAssertEqual(backoff.recordFailure(), 5 * minute)
    }

    func testDescribeFormatsMinutesAndHours() {
        // Sub minute delays only reach describe through an injected ladder, but "0m" would be a lie
        XCTAssertEqual(RateLimitBackoff.describe(0.01), "0s")
        XCTAssertEqual(RateLimitBackoff.describe(45), "45s")
        XCTAssertEqual(RateLimitBackoff.describe(1 * minute), "1m")
        XCTAssertEqual(RateLimitBackoff.describe(5 * minute), "5m")
        XCTAssertEqual(RateLimitBackoff.describe(30 * minute), "30m")
        XCTAssertEqual(RateLimitBackoff.describe(1 * hour), "1h")
        XCTAssertEqual(RateLimitBackoff.describe(12 * hour), "12h")
        XCTAssertEqual(RateLimitBackoff.describe(90 * minute), "1h 30m")
        // The full ladder adds up to 17h50m of waiting before it gives up
        XCTAssertEqual(RateLimitBackoff.describe(RateLimitBackoff.defaultDelays.reduce(0, +)), "17h 50m")
    }
}
