import Foundation

/// Decides how fast a long YouTube crawl runs while nothing is wrong.
///
/// `RateLimitBackoff` is recovery: it only engages once YouTube has already banned this IP. Recovery
/// on its own leaves a run sawtoothing between banned and hammering, which burns more wall clock
/// than crawling slower would have. The pacer is the other half of the problem, and the half that
/// matters more: the steady state rate is what decides whether the ban happens at all.
///
/// Three ideas do the work.
///
/// - Only requests are paced, never loop iterations. A video already on disk costs nothing, so a
///   resumed run scrolls past thirty thousand cached videos at full speed and spends its patience on
///   the few thousand that actually need fetching.
/// - Every wait is jittered. Perfectly even spacing is its own bot signature: nobody requests a page
///   exactly every 300ms and rests on exactly every seventeenth one. Jitter is the smaller half of
///   that fix though, because jitter around a mean that is too fast still earns the ban.
/// - The baseline adapts. YouTube does not publish the threshold it enforces and it moves, so no
///   hand picked constant is knowably safe. A rate limited fetch slows the whole rest of the run
///   down multiplicatively, and a long clean streak creeps the baseline back toward its floor, so a
///   run settles near whatever today's threshold turns out to be instead of trusting a guess.
///
/// Not thread safe, for the same reason `YouTubeRateLimiter` is not: one command, one task, one
/// request at a time. A reference type because the pacer is handed to helpers and mutated across
/// suspension points, where passing it `inout` would only invite exclusivity trouble later.
final class FetchPacer {
    /// An extra pause folded in on every `every`th fetch, on top of the per fetch baseline.
    struct Rest {
        let every: Int
        let seconds: TimeInterval

        init(every: Int, seconds: TimeInterval) {
            assert(every > 0, "an interval of \(every) would divide by zero on the next fetch")
            assert(seconds >= 0, "a negative rest would hand back time rather than spend it")
            self.every = every
            self.seconds = seconds
        }
    }

    /// Occasional longer pauses, so the crawl is not a metronome at the minute scale either.
    ///
    /// Fetches landing on two intervals at once take the longest matching rest rather than the first
    /// one found. Every 850th fetch is a multiple of both 17 and 50 and belongs to the 50 rest;
    /// every 4403rd is a multiple of both 17 and 259 and belongs to the 259 rest.
    static let defaultRests: [Rest] = [
        Rest(every: 17, seconds: 2),
        Rest(every: 50, seconds: 5),
        Rest(every: 37 * 7, seconds: 37)
    ]

    /// The starting pause between fetches, and the floor the adaptive baseline creeps back toward.
    /// The baseline never drops below it, so adapting can only ever slow a run down.
    let baseDelay: TimeInterval
    /// Ceiling on the baseline and on the target every wait jitters around, so a bad afternoon
    /// cannot stall the crawl outright. Rests stretch with the baseline and would otherwise sail
    /// past it: at a 60s baseline an unclamped 37s rest becomes 18 minutes, which is the stall this
    /// is meant to prevent.
    ///
    /// It bounds the target rather than the wait, so an individual wait can still land up to
    /// `1 + jitter` above it. See `wait(_:)` for why that is the lesser evil.
    let maxDelay: TimeInterval
    /// The pause before a thumbnail download that actually reaches the network.
    ///
    /// Thumbnails go to i.ytimg.com rather than to youtube.com. Whether Google weighs traffic to the
    /// two together is not something this code can know, so they are paced lightly rather than not
    /// at all: enough that a resumed run cannot fire thousands of image requests back to back,
    /// little enough that it does not dominate a run whose real work is elsewhere.
    let assetDelay: TimeInterval
    /// What the baseline is multiplied by each time a host rate limits us: once per rate limited
    /// response from youtube.com, and once per throttled thumbnail however many responses that
    /// download actually drew.
    let slowdownFactor: Double
    /// What the baseline is multiplied by once a clean streak completes. Deliberately gentler than
    /// `slowdownFactor`: give ground quickly, take it back slowly.
    let speedupFactor: Double
    /// Clean youtube.com fetches needed before the baseline creeps back down one notch.
    ///
    /// Only fetches, never thumbnails, and the asymmetry with `slowdownFactor` is deliberate:
    /// throttling at the asset host is decent evidence this IP is asking for too much and worth
    /// slowing down for, while a thumbnail that downloads cleanly says nothing about how youtube.com
    /// feels and is no reason to speed back up. Crediting it would let a resumed run whose
    /// thumbnails all miss the cache walk the baseline from the ceiling to the floor on the strength
    /// of a different host's opinion, without having asked youtube.com for anything at all.
    let cleanStreakForSpeedup: Int
    /// Half width of the jitter band as a fraction of the delay: 0.5 spreads 2s over 1s...3s.
    let jitter: Double

    private let rests: [Rest]
    private let randomFactor: (ClosedRange<Double>) -> Double
    private let now: () -> Date

    /// The current pause between fetches before jitter, somewhere in `baseDelay...maxDelay`.
    private(set) var currentDelay: TimeInterval
    /// Fetches that actually reached youtube.com, cached videos excluded.
    private(set) var fetchCount = 0
    /// youtube.com requests those fetches cost, which is not the same number: asking for a watch
    /// page with its transcript costs two, asking for the page alone costs one.
    private(set) var requestCount = 0
    /// Thumbnail downloads that actually reached i.ytimg.com.
    private(set) var assetFetchCount = 0
    /// Rate limited responses from youtube.com, including the ones the limiter waited out for us.
    private(set) var rateLimitCount = 0
    /// Thumbnail downloads the asset host throttled. Counted apart from `rateLimitCount` because
    /// they are not the same event: one is the IP ban that ends a run, the other is a busy image
    /// host, and a report that adds them together tells whoever reads it the wrong story.
    private(set) var assetRateLimitCount = 0

    private var cleanStreak = 0
    private var startedAt: Date?

    init(baseDelay: TimeInterval = 2,
         maxDelay: TimeInterval = 60,
         assetDelay: TimeInterval = 0.25,
         slowdownFactor: Double = 2,
         speedupFactor: Double = 0.9,
         cleanStreakForSpeedup: Int = 50,
         jitter: Double = 0.5,
         rests: [Rest] = FetchPacer.defaultRests,
         randomFactor: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) },
         now: @escaping () -> Date = Date.init) {
        assert(baseDelay > 0, "a zero baseline is the pacing bug this type exists to fix")
        assert(maxDelay >= baseDelay, "the ceiling cannot sit below the floor")
        assert(assetDelay >= 0, "a negative delay would hand back time rather than spend it")
        assert(slowdownFactor >= 1, "a rate limit has to slow the run down, not speed it up")
        assert(speedupFactor > 0 && speedupFactor <= 1, "a clean streak must not slow the run down")
        assert(cleanStreakForSpeedup > 0, "recovering takes at least one clean fetch")
        assert(jitter >= 0 && jitter < 1, "jitter of \(jitter) would allow a negative delay")

        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.assetDelay = assetDelay
        self.slowdownFactor = slowdownFactor
        self.speedupFactor = speedupFactor
        self.cleanStreakForSpeedup = cleanStreakForSpeedup
        self.jitter = jitter
        self.rests = rests
        self.randomFactor = randomFactor
        self.now = now
        self.currentDelay = baseDelay
    }

    /// How long to wait before the next YouTube fetch, counting that fetch as issued.
    ///
    /// `requests` is what the fetch is expected to cost on the wire, which the call site can
    /// estimate and the pacer cannot: asking for a watch page with its transcript is two requests,
    /// asking for the page alone is one. It is an estimate rather than a count - a video whose
    /// captions turn out to be missing never makes the second request, and a video needing a
    /// fallback caption track can make more - so it is close in the common case and not authoritative
    /// in any of them. Only the rate report reads it, where being approximately right is the job.
    ///
    /// Call this immediately before a fetch and sleep for what it hands back. Counting here rather
    /// than on completion is what keeps the rest schedule tied to requests actually sent.
    func delayBeforeNextFetch(requests: Int) -> TimeInterval {
        assert(requests > 0, "a fetch that costs nothing does not need pacing")
        startClock()
        fetchCount += 1
        requestCount += requests

        // Rests stretch along with the baseline, so a run that a ban has slowed down keeps the shape
        // of its pacing profile instead of resting on the old, now proportionally shorter, schedule
        let rest = FetchPacer.rest(beforeFetch: fetchCount, in: rests)
        return wait(currentDelay + rest * stretch)
    }

    /// How long to wait before a thumbnail download that will actually reach the network.
    ///
    /// Only for downloads that miss the on disk cache. A thumbnail already downloaded costs no
    /// request and must not cost a delay either, or a resumed run pays for every asset it already
    /// has, which is the loop shaped mistake this type exists to avoid.
    func delayBeforeNextAssetFetch() -> TimeInterval {
        startClock()
        assetFetchCount += 1
        return wait(assetDelay * stretch)
    }

    /// Records how a fetch went, where `rateLimits` counts the rate limited responses it drew.
    ///
    /// The count has to come from the limiter rather than from a thrown error, because the limiter
    /// swallows the bans it successfully waits out. From the caller's side a fetch that was banned
    /// twice and then succeeded looks identical to one that sailed straight through, and pacing
    /// those two the same way afterward is exactly how a run walks back into the ban it just left.
    func recordOutcome(rateLimits: Int) {
        guard rateLimits > 0 else {
            creditCleanRequest()
            return
        }

        rateLimitCount += rateLimits
        slowDown(steps: rateLimits)
    }

    /// Records that the asset host throttled a thumbnail download.
    ///
    /// One signal per download rather than one per rate limited response, because the asset host
    /// retries internally and can absorb several 429s in a couple of seconds. Slowing the run down
    /// once per absorbed response would let a single busy thumbnail cost more than a real IP ban.
    ///
    /// There is deliberately no clean counterpart. Being throttled anywhere is evidence this IP is
    /// asking for too much, so it is worth acting on wherever it comes from; a thumbnail arriving
    /// cleanly is not evidence about youtube.com and must not buy a speedup there. See
    /// `cleanStreakForSpeedup`. The ratchet that asymmetry usually implies does not bite here,
    /// because the clean fetches that do credit the streak are the same ones the baseline governs.
    func recordAssetThrottle() {
        assetRateLimitCount += 1
        slowDown(steps: 1)
    }

    private func creditCleanRequest() {
        cleanStreak += 1
        guard cleanStreak >= cleanStreakForSpeedup else { return }
        cleanStreak = 0
        currentDelay = max(baseDelay, currentDelay * speedupFactor)
    }

    private func slowDown(steps: Int) {
        cleanStreak = 0
        currentDelay = min(maxDelay, currentDelay * pow(slowdownFactor, Double(steps)))
    }

    /// One line describing how hard this run is leaning on YouTube, or nil before the first request.
    ///
    /// Printed periodically so a run drifting toward a ban is diagnosable while it is drifting,
    /// rather than from the wreckage afterward.
    func rateReport() -> String? {
        guard let startedAt = startedAt else { return nil }

        // Clamped so the first report of a run cannot divide by a rounding error and claim
        // thousands of requests a minute
        let elapsed = max(now().timeIntervalSince(startedAt), 1)
        let requestsPerMinute = Double(requestCount) / elapsed * 60

        var report = String(format: "pacing: %@ (%@) in %@, ~%.1f req/min, baseline %.1fs, %@",
                            FetchPacer.counted(fetchCount, "fetch", "fetches"),
                            FetchPacer.counted(requestCount, "request", "requests"),
                            RateLimitBackoff.describe(elapsed),
                            requestsPerMinute,
                            currentDelay,
                            FetchPacer.counted(rateLimitCount, "rate limit", "rate limits"))

        // Named only when there are any, since most runs download no thumbnails at all
        if assetFetchCount > 0 {
            report += ", " + FetchPacer.counted(assetFetchCount, "thumbnail", "thumbnails")
            if assetRateLimitCount > 0 {
                report += " (\(assetRateLimitCount) throttled)"
            }
        }
        return report
    }

    /// The longest rest that lands on this fetch, or zero when none of them do.
    static func rest(beforeFetch count: Int, in rests: [Rest]) -> TimeInterval {
        // Longest wins rather than first match: a fetch on two intervals at once should get the rest
        // its rarer interval asked for instead of being cut short by the common one
        return rests.filter { count % $0.every == 0 }.map { $0.seconds }.max() ?? 0
    }

    /// How far the baseline has been stretched from its floor, applied to every other wait so the
    /// whole pacing profile slows together rather than only the gaps between fetches.
    private var stretch: Double {
        return currentDelay / baseDelay
    }

    /// Holds a delay under the ceiling, then jitters it.
    ///
    /// This order matters more than it looks. Clamping last would bound every individual wait, which
    /// reads like the stricter guarantee, but `min` does not redistribute - it piles every delay that
    /// was over the ceiling onto exactly `maxDelay`. Once a run is slow enough for the clamp to bind,
    /// which the 259 rest reaches after two bans, that turns a large share of waits into the same
    /// number to the millisecond: a fixed interval fingerprint, which is the exact thing jitter is
    /// here to avoid, arriving precisely when the run is already in trouble. It would also make the
    /// reported baseline a lie, since the mean of a clamped band sits below the target it prints.
    ///
    /// Clamping the target first keeps the distribution continuous. The cost is that a single wait
    /// can land up to `1 + jitter` above `maxDelay` - 90s at the defaults - which is a pause, not the
    /// stall the ceiling exists to prevent.
    private func wait(_ delay: TimeInterval) -> TimeInterval {
        return jittered(min(delay, maxDelay))
    }

    private func jittered(_ delay: TimeInterval) -> TimeInterval {
        guard jitter > 0 else { return delay }
        return delay * randomFactor((1 - jitter)...(1 + jitter))
    }

    /// Starts the clock the rate report measures against, on the first request of any kind.
    private func startClock() {
        if startedAt == nil {
            startedAt = now()
        }
    }

    private static func counted(_ value: Int, _ singular: String, _ plural: String) -> String {
        return "\(value) \(value == 1 ? singular : plural)"
    }
}
