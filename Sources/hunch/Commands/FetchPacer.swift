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
/// - Only fetches are paced, never loop iterations. A video already on disk costs YouTube nothing,
///   so a resumed run scrolls past thirty thousand cached videos at full speed and spends its
///   patience on the few thousand that actually need fetching.
/// - Every wait is jittered. Perfectly even spacing is its own bot signature: nobody requests a page
///   exactly every 300ms and rests on exactly every seventeenth one. Jitter is the smaller half of
///   that fix though, because jitter around a mean that is too fast still earns the ban.
/// - The baseline adapts. YouTube does not publish the threshold it enforces and it moves, so no
///   hand picked constant is knowably safe. A rate limited fetch slows the whole rest of the run
///   down multiplicatively, and a long clean streak creeps the baseline back toward its floor, so a
///   run settles near whatever today's threshold turns out to be instead of trusting a guess.
///
/// Not thread safe, for the same reason `YouTubeRateLimiter` is not: one command, one task, one
/// fetch at a time. A reference type because the pacer is handed to helpers and mutated across
/// suspension points, where passing it `inout` would only invite exclusivity trouble later.
final class FetchPacer {
    /// An extra pause folded in on every `every`th fetch, on top of the per fetch baseline.
    struct Rest {
        let every: Int
        let seconds: TimeInterval

        init(every: Int, seconds: TimeInterval) {
            assert(every > 0, "a rest interval of \(every) would fire on every fetch or on none")
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

    /// Roughly what one fetch costs in youtube.com requests: the watch page, then a second request
    /// for the caption track. Thumbnails add more but go to i.ytimg.com, which is not the host doing
    /// the banning. Only used to report the rate, never to compute a delay.
    static let requestsPerFetch = 2

    /// The starting pause between fetches, and the floor the adaptive baseline creeps back toward.
    /// The baseline never drops below it, so adapting can only ever slow a run down.
    let baseDelay: TimeInterval
    /// Ceiling on the adaptive baseline, so a bad afternoon cannot stall the crawl outright.
    let maxDelay: TimeInterval
    /// What the baseline is multiplied by each time YouTube rate limits us.
    let slowdownFactor: Double
    /// What the baseline is multiplied by once a clean streak completes. Deliberately gentler than
    /// `slowdownFactor`: give ground quickly, take it back slowly.
    let speedupFactor: Double
    /// Clean fetches needed before the baseline creeps back down one notch.
    let cleanStreakForSpeedup: Int
    /// Half width of the jitter band as a fraction of the delay: 0.5 spreads 2s over 1s...3s.
    let jitter: Double

    private let rests: [Rest]
    private let randomFactor: (ClosedRange<Double>) -> Double
    private let now: () -> Date

    /// The current pause between fetches before jitter, somewhere in `baseDelay...maxDelay`.
    private(set) var currentDelay: TimeInterval
    /// Fetches that actually reached the network, cached videos excluded.
    private(set) var fetchCount = 0
    /// Rate limited responses seen so far, including the ones the limiter waited out for us.
    private(set) var rateLimitCount = 0

    private var cleanStreak = 0
    private var firstFetchAt: Date?

    init(baseDelay: TimeInterval = 2,
         maxDelay: TimeInterval = 60,
         slowdownFactor: Double = 2,
         speedupFactor: Double = 0.9,
         cleanStreakForSpeedup: Int = 50,
         jitter: Double = 0.5,
         rests: [Rest] = FetchPacer.defaultRests,
         randomFactor: @escaping (ClosedRange<Double>) -> Double = { Double.random(in: $0) },
         now: @escaping () -> Date = Date.init) {
        assert(baseDelay > 0, "a zero baseline is the pacing bug this type exists to fix")
        assert(maxDelay >= baseDelay, "the ceiling cannot sit below the floor")
        assert(slowdownFactor >= 1, "a rate limit has to slow the run down, not speed it up")
        assert(speedupFactor > 0 && speedupFactor <= 1, "a clean streak must not slow the run down")
        assert(cleanStreakForSpeedup > 0, "recovering takes at least one clean fetch")
        assert(jitter >= 0 && jitter < 1, "jitter of \(jitter) would allow a negative delay")

        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
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
    /// Call it immediately before a fetch and sleep for what it hands back. Counting here rather
    /// than on completion is what keeps the rest schedule tied to requests actually sent.
    func delayBeforeNextFetch() -> TimeInterval {
        fetchCount += 1
        if firstFetchAt == nil {
            firstFetchAt = now()
        }

        // Rests stretch along with the baseline, so a run that a ban has slowed down keeps the shape
        // of its pacing profile instead of resting on the old, now proportionally shorter, schedule
        let stretch = currentDelay / baseDelay
        let rest = FetchPacer.rest(beforeFetch: fetchCount, in: rests)
        return jittered(currentDelay + rest * stretch)
    }

    /// Records how a fetch went, where `rateLimits` counts the rate limited responses YouTube gave
    /// while it ran.
    ///
    /// The count has to come from the limiter rather than from a thrown error, because the limiter
    /// swallows the bans it successfully waits out. From the caller's side a fetch that was banned
    /// twice and then succeeded looks identical to one that sailed straight through, and pacing
    /// those two the same way afterward is exactly how a run walks back into the ban it just left.
    func recordOutcome(rateLimits: Int) {
        guard rateLimits > 0 else {
            cleanStreak += 1
            guard cleanStreak >= cleanStreakForSpeedup else { return }
            cleanStreak = 0
            currentDelay = max(baseDelay, currentDelay * speedupFactor)
            return
        }

        rateLimitCount += rateLimits
        cleanStreak = 0
        currentDelay = min(maxDelay, currentDelay * pow(slowdownFactor, Double(rateLimits)))
    }

    /// One line describing how hard this run is leaning on YouTube, or nil before the first fetch.
    ///
    /// Printed periodically so a run drifting toward a ban is diagnosable while it is drifting,
    /// rather than from the wreckage afterward.
    func rateReport() -> String? {
        guard let firstFetchAt = firstFetchAt else { return nil }

        // Clamped so the first report of a run cannot divide by a rounding error and claim
        // thousands of requests a minute
        let elapsed = max(now().timeIntervalSince(firstFetchAt), 1)
        let requestsPerMinute = Double(fetchCount * FetchPacer.requestsPerFetch) / elapsed * 60
        let limits = rateLimitCount == 1 ? "1 rate limit" : "\(rateLimitCount) rate limits"

        return String(format: "pacing: %d fetches in %@, ~%.1f req/min, baseline %.1fs, %@",
                      fetchCount, RateLimitBackoff.describe(elapsed), requestsPerMinute, currentDelay, limits)
    }

    /// The longest rest that lands on this fetch, or zero when none of them do.
    static func rest(beforeFetch count: Int, in rests: [Rest]) -> TimeInterval {
        // Longest wins rather than first match: a fetch on two intervals at once should get the rest
        // its rarer interval asked for instead of being cut short by the common one
        return rests.filter { count % $0.every == 0 }.map { $0.seconds }.max() ?? 0
    }

    private func jittered(_ delay: TimeInterval) -> TimeInterval {
        guard jitter > 0 else { return delay }
        return delay * randomFactor((1 - jitter)...(1 + jitter))
    }
}
