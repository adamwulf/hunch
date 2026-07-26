@testable import hunch
import XCTest

final class FetchPacerTests: XCTestCase {
    /// A pacer with the jitter dial pinned, so a test can assert on the delay itself rather than on
    /// a band. Jitter gets its own tests below.
    private func steadyPacer(baseDelay: TimeInterval = 2,
                             maxDelay: TimeInterval = 60,
                             assetDelay: TimeInterval = 0.25,
                             slowdownFactor: Double = 2,
                             speedupFactor: Double = 0.9,
                             cleanStreakForSpeedup: Int = 50,
                             rests: [FetchPacer.Rest] = FetchPacer.defaultRests,
                             now: @escaping () -> Date = Date.init) -> FetchPacer {
        return FetchPacer(baseDelay: baseDelay,
                          maxDelay: maxDelay,
                          assetDelay: assetDelay,
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
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 2, accuracy: 0.0001)
    }

    func testRestsAreAddedOnTopOfTheBaseline() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 3, seconds: 5)])

        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 2, accuracy: 0.0001)
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 2, accuracy: 0.0001)
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 7, accuracy: 0.0001, "the third fetch rests on top of the baseline")
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 2, accuracy: 0.0001)
    }

    /// Only fetches advance the schedule. Nothing else can: a cached video never asks the pacer for
    /// a delay, which is what keeps a resumed run from resting between videos it already has.
    func testOnlyFetchesAdvanceTheRestSchedule() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 2, seconds: 5)])

        XCTAssertEqual(pacer.fetchCount, 0)
        _ = pacer.delayBeforeNextFetch(requests: 2)
        pacer.recordOutcome(rateLimits: 0)
        pacer.recordOutcome(rateLimits: 0)
        _ = pacer.delayBeforeNextAssetFetch()

        XCTAssertEqual(pacer.fetchCount, 1, "outcomes and asset downloads must not advance the fetch count")
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 7, accuracy: 0.0001, "the rest lands on the second fetch")
    }

    // MARK: - Jitter

    func testDelaysAreJitteredSymmetricallyAroundTheBaseline() {
        var bands: [ClosedRange<Double>] = []
        let pacer = FetchPacer(baseDelay: 2, jitter: 0.5, randomFactor: { band in
            bands.append(band)
            return band.lowerBound
        })

        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 1, accuracy: 0.0001, "the bottom of the band is half the baseline")
        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands.first?.lowerBound ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(bands.first?.upperBound ?? 0, 1.5, accuracy: 0.0001, "a 2s baseline should spread over 1s...3s")
    }

    func testJitterAppliesToRestsToo() {
        let pacer = FetchPacer(baseDelay: 2,
                               jitter: 0.5,
                               rests: [FetchPacer.Rest(every: 1, seconds: 2)],
                               randomFactor: { $0.upperBound })

        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 6, accuracy: 0.0001, "a rest is a wait, and every wait is jittered")
    }

    // MARK: - The ceiling

    /// Rests stretch with the baseline, and unclamped that arithmetic ran away: at the 60s ceiling a
    /// 37s rest stretches 30x into a 19 minute sleep, and jitter pushed it to 29. maxDelay has to
    /// bound the target a wait is computed from, not just the baseline underneath it.
    func testTheCeilingBoundsTheTargetAndNotJustTheBaseline() {
        let pacer = steadyPacer(rests: [FetchPacer.Rest(every: 1, seconds: 37)])

        // 2 * 2^5 is 64, over the 60s ceiling, so the baseline pins at 60 and stretch reaches 30x
        pacer.recordOutcome(rateLimits: 5)
        XCTAssertEqual(pacer.currentDelay, 60, accuracy: 0.0001)
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 60, accuracy: 0.0001,
                       "an unclamped stretch would have returned 1170s here")
    }

    /// The clamp lands on the target rather than on the result, and that ordering is the point.
    /// Clamping last bounds every individual wait, which sounds stricter, but `min` does not
    /// redistribute - it piles every over-ceiling delay onto exactly `maxDelay`. Once the clamp began
    /// to bind, a large share of waits became the same number to the millisecond: the fixed interval
    /// fingerprint jitter is here to remove, arriving exactly when a run is already in trouble.
    func testTheClampedTargetStillJittersInBothDirections() {
        func pacerAtTheCeiling(_ factor: @escaping (ClosedRange<Double>) -> Double) -> FetchPacer {
            let pacer = FetchPacer(baseDelay: 2,
                                   maxDelay: 60,
                                   jitter: 0.5,
                                   rests: [FetchPacer.Rest(every: 1, seconds: 37)],
                                   randomFactor: factor)
            pacer.recordOutcome(rateLimits: 5)
            return pacer
        }

        XCTAssertEqual(pacerAtTheCeiling({ $0.lowerBound }).delayBeforeNextFetch(requests: 2), 30, accuracy: 0.0001,
                       "a clamped target still jitters down")
        XCTAssertEqual(pacerAtTheCeiling({ $0.upperBound }).delayBeforeNextFetch(requests: 2), 90, accuracy: 0.0001,
                       "and up, which is a long pause rather than the stall the ceiling exists to prevent")
    }

    /// The earlier version of this asked only that a thumbnail wait stay under 60s, which it does by
    /// a factor of five whether or not anything clamps it. An assertion that cannot fail is worse
    /// than no assertion, because it advertises coverage that is not there.
    func testTheCeilingBoundsThumbnailWaitsToo() {
        let pacer = steadyPacer(assetDelay: 40)

        pacer.recordOutcome(rateLimits: 5)
        XCTAssertEqual(pacer.delayBeforeNextAssetFetch(), 60, accuracy: 0.0001,
                       "40s stretched 30x is 20 minutes of waiting for one image")
    }

    /// The ceiling must not bite during an ordinary run, or it would flatten the rest schedule the
    /// rest of this type exists to shape. The longest scheduled wait is the 259th fetch at full
    /// jitter: (2 + 37) * 1.5.
    func testTheCeilingLeavesAHealthyRunAlone() {
        let pacer = FetchPacer(baseDelay: 2,
                               maxDelay: 60,
                               jitter: 0.5,
                               rests: [FetchPacer.Rest(every: 1, seconds: 37)],
                               randomFactor: { $0.upperBound })

        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 58.5, accuracy: 0.0001, "the worst healthy case still fits under the cap")
    }

    // MARK: - Thumbnails

    /// Thumbnails are a different host and a lighter touch, but they are not free: a resumed run
    /// whose thumbnails failed once will ask for them again on every future run, and unpaced that is
    /// thousands of image requests back to back.
    func testAssetDownloadsArePacedLightlyAndCountedSeparately() {
        let pacer = steadyPacer(assetDelay: 0.25)

        XCTAssertEqual(pacer.delayBeforeNextAssetFetch(), 0.25, accuracy: 0.0001)
        XCTAssertEqual(pacer.assetFetchCount, 1)
        XCTAssertEqual(pacer.fetchCount, 0, "a thumbnail is not a YouTube fetch")
        XCTAssertEqual(pacer.requestCount, 0, "and it is not a youtube.com request either")
    }

    /// However many 429s the downloader's own retry loop absorbed, one throttled download is one
    /// signal. Slowing down once per absorbed response would let a single busy thumbnail cost a run
    /// more than a real IP ban does.
    func testAThrottledThumbnailSlowsTheRunOnce() {
        let pacer = steadyPacer()

        pacer.recordAssetOutcome(throttled: true)

        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)
        XCTAssertEqual(pacer.assetRateLimitCount, 1)
        XCTAssertEqual(pacer.rateLimitCount, 0, "a busy image host is not the IP ban that ends a run")
    }

    /// A signal that can only ever slow a run down and never give anything back is a ratchet rather
    /// than a control loop, so a clean thumbnail credits the streak like any other clean request.
    func testACleanThumbnailCreditsTheStreak() {
        let pacer = steadyPacer(speedupFactor: 0.5, cleanStreakForSpeedup: 2)

        pacer.recordAssetOutcome(throttled: true)
        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)

        pacer.recordAssetOutcome(throttled: false)
        pacer.recordAssetOutcome(throttled: false)
        XCTAssertEqual(pacer.currentDelay, 2, accuracy: 0.0001)
    }

    func testAssetDownloadsStretchWithTheSlowedBaseline() {
        let pacer = steadyPacer(assetDelay: 0.25)

        pacer.recordOutcome(rateLimits: 2)
        XCTAssertEqual(pacer.delayBeforeNextAssetFetch(), 1, accuracy: 0.0001,
                       "a 4x slower baseline should slow the asset host too, 0.25 * 4")
    }

    // MARK: - Adapting to rate limits

    func testARateLimitSlowsEveryLaterFetch() {
        let pacer = steadyPacer()

        _ = pacer.delayBeforeNextFetch(requests: 2)
        pacer.recordOutcome(rateLimits: 1)

        XCTAssertEqual(pacer.currentDelay, 4, accuracy: 0.0001)
        XCTAssertEqual(pacer.rateLimitCount, 1)
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 4, accuracy: 0.0001, "the slowdown outlives the fetch that caused it")

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
        XCTAssertEqual(pacer.delayBeforeNextFetch(requests: 2), 10, accuracy: 0.0001,
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

    func testThereIsNothingToReportBeforeTheFirstRequest() {
        XCTAssertNil(steadyPacer().rateReport(), "a run that has not asked for anything has no rate yet")
    }

    /// Fetches and requests are different numbers, which is the whole reason the call site passes
    /// its own cost: a watch page with its transcript is two requests, the page alone is one.
    func testTheRateReportCountsRequestsRatherThanFetches() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        _ = pacer.delayBeforeNextFetch(requests: 2)
        _ = pacer.delayBeforeNextFetch(requests: 2)
        _ = pacer.delayBeforeNextFetch(requests: 1)
        clock = clock.addingTimeInterval(60)

        XCTAssertEqual(pacer.rateReport(), "pacing: 3 fetches (5 requests) in 1m, ~5.0 req/min, baseline 2.0s, 0 rate limits")
    }

    func testTheRateReportSaysEveryCountInTheSingularWhenItIsOne() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        _ = pacer.delayBeforeNextFetch(requests: 1)
        pacer.recordOutcome(rateLimits: 1)
        _ = pacer.delayBeforeNextAssetFetch()
        clock = clock.addingTimeInterval(120)

        XCTAssertEqual(pacer.rateReport(),
                       "pacing: 1 fetch (1 request) in 2m, ~0.5 req/min, baseline 4.0s, 1 rate limit, 1 thumbnail")
    }

    /// The two hosts are counted apart. One is the IP ban that ends a run, the other is a busy image
    /// host, and a line that adds them together tells whoever reads it the wrong story.
    func testTheReportKeepsThumbnailThrottlesApartFromYouTubeBans() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        _ = pacer.delayBeforeNextFetch(requests: 2)
        pacer.recordOutcome(rateLimits: 1)
        _ = pacer.delayBeforeNextAssetFetch()
        pacer.recordAssetOutcome(throttled: true)
        clock = clock.addingTimeInterval(60)

        XCTAssertEqual(pacer.rateReport(),
                       "pacing: 1 fetch (2 requests) in 1m, ~2.0 req/min, baseline 8.0s, 1 rate limit, 1 thumbnail (1 throttled)")
    }

    /// A resumed run can download thumbnails long before it needs to fetch anything, and that is
    /// exactly the run worth watching, so the clock starts on whichever request comes first.
    func testThumbnailsAloneStillProduceAReport() {
        var clock = Date(timeIntervalSince1970: 0)
        let pacer = steadyPacer(now: { clock })

        _ = pacer.delayBeforeNextAssetFetch()
        _ = pacer.delayBeforeNextAssetFetch()
        clock = clock.addingTimeInterval(60)

        XCTAssertEqual(pacer.rateReport(),
                       "pacing: 0 fetches (0 requests) in 1m, ~0.0 req/min, baseline 2.0s, 0 rate limits, 2 thumbnails")
    }
}
