@testable import hunch
import XCTest

final class FetchPacerTests: XCTestCase {
    /// A pacer with the jitter dial pinned, so a test can assert on the delay itself rather than on
    /// a band. Jitter gets its own test below.
    private func steadyPacer(baseDelay: TimeInterval = 2,
                             maxDelay: TimeInterval = 60,
                             slowdownFactor: Double = 2,
                             speedupFactor: Double = 0.9,
                             cleanStreakForSpeedup: Int = 50,
                             rests: [FetchPacer.Rest] = FetchPacer.defaultRests,
                             now: @escaping () -> Date = Date.init) -> FetchPacer {
        return FetchPacer(baseDelay: baseDelay,
                          maxDelay: maxDelay,
                          slowdownFactor: slowdownFactor,
                          speedupFactor: speedupFactor,
                          cleanStreakForSpeedup: cleanStreakForSpeedup,
                          jitter: 0,
                          rests: rests,
                          randomFactor: { _ in 1 },
                          now: now)
    }

    // MARK: - Rests

    /// The bug this replaced: an if/else-if chain checked `% 17` first, so a fetch landing on two
    /// intervals at once silently took the shorter rest. 850 is a multiple of both 17 and 50 and was
    /// getting 2s instead of 5s.
    func testLongestRestWinsWhenTwoIntervalsLandOnTheSameFetch() {
        let rests = FetchPacer.defaultRests

        XCTAssertEqual(FetchPacer.rest(beforeFetch: 17 * 50, in: rests), 5, "850 belongs to the 50 rest, not the 17 rest")
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 17 * 37 * 7, in: rests), 37, "4403 belongs to the 259 rest")

        // The intervals that only match one rest each, as a control
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 17, in: rests), 2)
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 50, in: rests), 5)
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 37 * 7, in: rests), 37)
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 16, in: rests), 0)
    }

    /// Counting fetches from one rather than zero is what retires the old `index > 0` guard: the
    /// first fetch of a run can never be a multiple of anything.
    func testTheFirstFetchNeverRests() {
        XCTAssertEqual(FetchPacer.rest(beforeFetch: 1, in: FetchPacer.defaultRests), 0)

        let pacer = steadyPacer()
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 2, accuracy: 0.0001)
    }

    func testRestsAreAddedOnTopOfTheBaseline() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 3, seconds: 5)])

        XCTAssertEqual(pacer.delayBeforeNextFetch(), 2, accuracy: 0.0001)
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 2, accuracy: 0.0001)
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 7, accuracy: 0.0001, "the third fetch rests on top of the baseline")
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 2, accuracy: 0.0001)
    }

    /// Only fetches advance the schedule. Nothing else can: a cached video never asks the pacer for
    /// a delay, which is what keeps a resumed run from resting between videos it already has.
    func testOnlyFetchesAdvanceTheRestSchedule() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 2, seconds: 5)])

        XCTAssertEqual(pacer.fetchCount, 0)
        _ = pacer.delayBeforeNextFetch()
        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 0)

        XCTAssertEqual(pacer.fetchCount, 1, "recording outcomes must not advance the fetch count")
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 7, accuracy: 0.0001, "the rest lands on the second fetch")
    }

    // MARK: - Jitter

    func testDelaysAreJitteredSymmetricallyAroundTheBaseline() {
        var bands: [ClosedRange<Double>] = []
        let pacer = FetchPacer(baseDelay: 2, jitter: 0.5, randomFactor: { band in
            bands.append(band)
            return band.lowerBound
        })

        XCTAssertEqual(pacer.delayBeforeNextFetch(), 1, accuracy: 0.0001, "the bottom of the band is half the baseline")
        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands.first?.lowerBound ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(bands.first?.upperBound ?? 0, 1.5, accuracy: 0.0001, "a 2s baseline should spread over 1s...3s")
    }

    func testJitterAppliesToRestsToo() {
        let pacer = FetchPacer(baseDelay: 2,
                               jitter: 0.5,
                               rests: [FetchPacer.Rest(every: 1, seconds: 2)],
                               randomFactor: { $0.upperBound })

        XCTAssertEqual(pacer.delayBeforeNextFetch(), 6, accuracy: 0.0001, "a rest is a wait, and every wait is jittered")
    }

    // MARK: - Adapting to rate limits

    func testARateLimitSlowsEveryLaterFetch() {
        let pacer = steadyPacer()

        _ = pacer.delayBeforeNextFetch()
        pacer.recordOutcome(rateLimits: 1)

        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)
        XCTAssertEqual(pacer.rateLimitCount, 1)
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 4, accuracy: 0.0001, "the slowdown outlives the fetch that caused it")

        // A handful of clean fetches is not a streak, so the run stays slow
        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)
    }

    func testRateLimitsCompoundAndStopAtTheCeiling() {
        let pacer = steadyPacer(maxDelay: 10)

        // Two bans inside one fetch, because backoff climbed a rung and got banned again
        pacer.recordOutcome(rateLimits: 2)
        XCTAssertEqual(pacer.currentDelay, 8, accuracy: 0.0001)
        XCTAssertEqual(pacer.rateLimitCount, 2, "every banned response counts, not every banned fetch")

        pacer.recordOutcome(rateLimits: 1)
        XCTAssertEqual(pacer.currentDelay, 10, accuracy: 0.0001, "a bad afternoon must not stall the crawl outright")
    }

    func testRestsStretchWithTheSlowedBaseline() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 1, seconds: 3)])

        pacer.recordOutcome(rateLimits: 1)
        XCTAssertEqual(pacer.delayBeforeNextFetch(), 10, accuracy: 0.0001,
                       "doubling the baseline should double the rest with it, 4 + 3 * 2")
    }

    func testACleanStreakCreepsTheBaselineBackDownButNeverBelowTheFloor() {
        let pacer = steadyPacer(speedupFactor: 0.5, cleanStreakForSpeedup: 2)

        pacer.recordOutcome(rateLimits: 2)
        XCTAssertEqual(pacer.currentDelay, 8, accuracy: 0.0001)

        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 8, accuracy: 0.0001, "one clean fetch is not a streak")
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001, "a completed streak gives back one notch")

        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 2, accuracy: 0.0001)

        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 2, accuracy: 0.0001, "adapting can only ever slow a run down")
    }

    func testARateLimitRestartsTheCleanStreak() {
        let pacer = steadyPacer(speedupFactor: 0.5, cleanStreakForSpeedup: 2)

        pacer.recordOutcome(rateLimits: 1)
        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 1)
        XCTAssertEqual(pacer.currentDelay, 8, accuracy: 0.0001)

        // The clean fetch before the second ban must not count toward the next streak
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 8, accuracy: 0.0001)
        pacer.recordOutcome(rateLimits: 0)
        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)
    }

    // MARK: - Rate reporting

    func testThereIsNothingToReportBeforeTheFirstFetch() {
        XCTAssertNil(steadyPacer().rateReport(), "a run that has not fetched anything has no rate yet")
    }

    func testTheRateReportCountsBothRequestsPerFetch() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        for _ in 0..<3 {
            _ = pacer.delayBeforeNextFetch()
        }
        clock = clock.addingTimeInterval(60)

        XCTAssertEqual(pacer.rateReport(), "pacing: 3 fetches in 1m, ~6.0 req/min, baseline 2.0s, 0 rate limits",
                       "3 fetches is 6 youtube.com requests: a watch page and a caption track apiece")
    }

    func testTheRateReportNamesASingleRateLimitInTheSingular() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        _ = pacer.delayBeforeNextFetch()
        pacer.recordOutcome(rateLimits: 1)
        clock = clock.addingTimeInterval(120)

        XCTAssertEqual(pacer.rateReport(), "pacing: 1 fetches in 2m, ~1.0 req/min, baseline 4.0s, 1 rate limit")
    }
}
