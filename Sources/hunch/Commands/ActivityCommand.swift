import Foundation
import ArgumentParser
import YouTubeTranscriptKit
import HunchKit

struct ActivityCommand: AsyncParsableCommand {
    private struct VideoData {
        let id: String
        let activities: [Activity]
        let firstSeen: Date
        let lastSeen: Date

        var title: String? {
            activities.reversed().compactMap { activity in
                if case .video(_, let title) = activity.link {
                    return title
                }
                return nil
            }.first
        }

        init(id: String, activities: [Activity]) {
            self.id = id
            self.activities = activities.sorted { $0.timestamp < $1.timestamp }
            self.firstSeen = activities.map { $0.timestamp }.min() ?? Date()
            self.lastSeen = activities.map { $0.timestamp }.max() ?? Date()
        }
    }

    /// The transcript content.md renders, and what its frontmatter says about where it came from.
    struct RenderedTranscript {
        let lines: [TranscriptLine]
        let source: TranscriptSource
    }

    static var configuration = CommandConfiguration(
        commandName: "activity",
        abstract: "Parse Google Takeout MyActivity.html file"
    )

    @Argument(help: "Path to MyActivity.html file")
    var activityPath: String

    @Option(name: .shortAndLong, help: "Output directory path")
    var outputDir: String = "./activity_export"

    /// An empty transcript.json is normally taken at its word and the video skipped without a
    /// request, which is right for as long as YouTube keeps refusing the tracks it refuses today.
    /// This is the way back: set it when there is reason to think that has changed, and every video
    /// cached as having no transcript is asked again.
    @Flag(name: .long, help: "Ask YouTube again for videos whose cached transcript is empty")
    var refetchEmptyTranscripts = false

    /// A video recorded as permanently unavailable is skipped without a request, which is right for
    /// as long as YouTube keeps saying it is gone. This is the way back: set it when there is reason
    /// to think that has changed - a private video made public again, a members-only video opened up
    /// - and every video with a marker is asked about again. Two requests each, or one where a
    /// transcript is already cached. Videos without a marker are untouched by it, so the flag costs
    /// nothing for the rest of the corpus.
    ///
    /// The marker needs this for the same reason an empty transcript.json does. A permanent answer
    /// written down with no expiry and no way to clear it is not a cache, it is a verdict, and this
    /// is the appeal.
    ///
    /// Nothing is recorded in transcript.json for a video that is gone, so one reopened by this flag
    /// is fetched from scratch with its captions. The exception is a folder that already holds a
    /// transcript - written before the video went away, or by a run older than this change - where
    /// only the info is fetched and --refetch-empty-transcripts is what reopens the rest.
    @Flag(name: .long, help: "Ask YouTube again for videos recorded as permanently unavailable")
    var recheckUnavailable = false

    mutating func run() async throws {
        let fm = FileManager.default

        // Normalize paths and convert to URLs
        let inputURL = URL(fileURLWithPath: ((activityPath as NSString)
            .expandingTildeInPath as NSString)
            .standardizingPath)
        let outputURL = URL(fileURLWithPath: ((outputDir as NSString)
            .expandingTildeInPath as NSString)
            .standardizingPath)

        // Create output directory if it doesn't exist
        try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

        // Parse activities and get sorted videos
        let sortedVideos = try await parseActivities(from: inputURL)
        print("Found \(sortedVideos.count) videos to process")

        // Configure encoder/decoder
        let encoder = ActivityCommand.artifactEncoder()
        let decoder = ActivityCommand.artifactDecoder()

        // Configure date formatter for progress
        let progressDateFormatter = DateFormatter()
        progressDateFormatter.dateFormat = "yyyy MMM"

        let skip = 0

        // Paces the fetches rather than the loop, so the videos already on disk cost nothing and
        // the whole pacing budget goes to the ones that actually touch YouTube
        let pacer = FetchPacer()

        var refusals = RefusalTally()

        // Process each video, pacing every fetch through `paced` below
        for (index, video) in sortedVideos[skip...].enumerated() {
            // Only print progress every 100 items
            if index % 100 == 0 {
                let trueIndex = index + skip
                let progress = Double(trueIndex) / Double(sortedVideos.count) * 100
                let dateStr = progressDateFormatter.string(from: video.lastSeen)
                let indexStr = "[\(trueIndex)/\(sortedVideos.count)]".padding(toLength: 15, withPad: " ", startingAt: 0)
                let dateColumn = dateStr.padding(toLength: 10, withPad: " ", startingAt: 0)
                let percentStr = String(format: "%6.1f%%", progress)
                print("\(indexStr) \(dateColumn) \(percentStr)")
                if let pacing = pacer.rateReport() {
                    print("  \(pacing)")
                }
                // Reported as the run goes rather than only at the end, so an export that is stopped
                // part way through still says how much it wrote down
                if let refusalReport = refusals.takeBlockSinceLastReport() {
                    print("  \(refusalReport)")
                }
            }

            // Build all URLs
            let videoURL = outputURL.appendingPathComponent(video.id + ".localized")
            let localizedURL = videoURL.appendingPathComponent(".localized")
            let activitiesURL = videoURL.appendingPathComponent("activities.json")
            let infoURL = videoURL.appendingPathComponent("info.json")
            let transcriptURL = videoURL.appendingPathComponent("transcript.json")
            let vttURL = videoURL.appendingPathComponent("transcript.vtt")
            let unavailableURL = videoURL.appendingPathComponent("unavailable.json")
            let stringsURL = localizedURL.appendingPathComponent("Base.strings")
            let assetsDir = videoURL.appendingPathComponent("assets")

            // Create initial directories
            try fm.createDirectory(at: videoURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: localizedURL, withIntermediateDirectories: true)

            // Verify directories were created
            var isDirectory: ObjCBool = false
            guard
                fm.fileExists(atPath: videoURL.path, isDirectory: &isDirectory), isDirectory.boolValue,
                fm.fileExists(atPath: localizedURL.path, isDirectory: &isDirectory), isDirectory.boolValue
            else {
                print("Error: Failed to create directories for video \(video.id)")
                throw NSError(domain: "ActivityCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create directories for video \(video.id)"])
            }

            var downloadedAssets: [String: FileDownloader.DownloadedAsset] = [:]

            // Load cached data
            let infoOnDisk: VideoInfo? = {
                guard let data = try? Data(contentsOf: infoURL) else { return nil }
                return try? decoder.decode(VideoInfo.self, from: data)
            }()

            // What is on disk, and then what the fetch below should make of it. The two are kept
            // apart because the flag only changes what gets asked for, never what gets believed
            // about the file: the render still has to describe the file that is actually there.
            let cached = ActivityCommand.cachedTranscript(at: transcriptURL, decoder: decoder)
            let transcript = ActivityCommand.transcriptToBuildOn(cached: cached, refetchEmpty: refetchEmptyTranscripts)

            // Read ahead of the fetch branches rather than inside them, because its whole purpose is
            // to keep a video YouTube has already said is gone from reaching them at all.
            let recorded = ActivityCommand.recordedUnavailability(at: unavailableURL, decoder: decoder)
            let knownGone = ActivityCommand.unavailabilityToTrust(recorded: recorded, recheck: recheckUnavailable)
            let info = ActivityCommand.infoToBuildOn(cached: infoOnDisk, recorded: recorded,
                                                     recheck: recheckUnavailable)

            // Process data with exponential backoff on failure
            let finalInfo: VideoInfo?
            let finalTranscript: [TranscriptMoment]?

            // What this iteration learned about whether the video can be fetched at all, and so what
            // unavailable.json should say once the writes below have run. Starts at "nothing
            // learned", which is the honest answer for every path that never asks.
            var availability = UnavailabilityOutcome.unchanged

            if let knownGone = knownGone {
                // Zero requests, which is the entire point. These videos used to spend two requests
                // apiece on every run, fail identically, and write down nothing that would stop the
                // next run repeating it.
                //
                // Deliberately ahead of --refetch-empty-transcripts. That flag reopens a video in
                // case YouTube has started serving captions it used to refuse, which cannot help a
                // video with no page left to serve them from; --recheck-unavailable is the flag that
                // reopens this one.
                refusals.recordSkippedAsUnavailable()
                finalInfo = infoOnDisk
                // Asked of the same rule the recording run used, from the status it recorded, so a
                // skipped run leaves disk exactly as that run did rather than by a second rule that
                // could drift from it.
                finalTranscript = ActivityCommand.transcriptAfterFailure(knownGone.asFailure, cached: cached)
            } else {
                do {
                    switch (info, transcript) {
                    case (nil, nil):
                        let fetched = try await paced(pacer, requests: 2) {
                            try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: true)
                        }
                        finalInfo = fetched.withoutTranscript()
                        // The kit swallows both refusals inside this call and returns a nil transcript
                        // for them, rethrowing anything transient - so a nil here is the same permanent
                        // answer the catch below records, and leaving it unwritten only bought this video
                        // one more two-request round trip before it settled
                        if fetched.transcript == nil {
                            refusals.recordCombinedFetch(cached: cached)
                        }
                        finalTranscript = fetched.transcript ?? ActivityCommand.transcriptAfterFailure(
                            .listedTracksWereEmpty, cached: cached)
                        print("Fetched \(video.id)\(fetched.transcript == nil ? "" : " with transcript")")
                        availability = .available
                    case (nil, .some(let cachedTranscript)):
                        print("Fetching info: \(video.id)")
                        let fetched = try await paced(pacer, requests: 1) {
                            try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: false)
                        }
                        finalInfo = fetched.withoutTranscript()
                        finalTranscript = cachedTranscript
                        availability = .available
                    case (.some(let cachedInfo), nil):
                        // Skip fetching transcript if we already have info
                        print("Fetching transcript: \(video.id)")
                        let moments = try await paced(pacer, requests: 2) {
                            try await YouTubeTranscriptKit.getTranscript(videoID: video.id)
                        }
                        // A returned transcript always has moments in it: the kit throws rather than
                        // hand back an empty one, and that throw is what the catch below records
                        finalInfo = cachedInfo
                        finalTranscript = moments
                        print("  recovered")
                        availability = .available
                    case (.some(let cachedInfo), .some(let cachedTranscript)):
                        // Nothing was asked, so nothing was learned. A marker cannot be sitting here
                        // unresolved: without --recheck-unavailable it short-circuits above, and with
                        // it the cached info is forgotten and the video takes a fetch branch instead.
                        finalInfo = cachedInfo
                        finalTranscript = cachedTranscript
                    }
                } catch let exhausted as YouTubeRateLimiter.RateLimitExhausted {
                    // Every rung of the ladder is spent and YouTube is still banning us, so stop the
                    // run rather than grind through the rest of the videos against a closed door.
                    throw exhausted
                } catch {
                    // The two refusals are answers rather than failures and the run writes them down
                    // below, so printing them here would put a line on screen for every video YouTube
                    // will not serve captions for. The tally is what keeps them visible in aggregate.
                    let failure = ActivityCommand.classifyFailure(error)
                    if case .unresolved = failure {
                        print("Error processing \(video.id): \(error)")
                    }

                    // Said once per video, unless --recheck-unavailable asks again: the marker written
                    // below means no ordinary run reaches here for it. Naming YouTube's own status is
                    // what makes the allowlist auditable from a run log afterwards, which matters for
                    // the one decision here that stops a video being asked about at all.
                    if case .permanentlyUnavailable(let status, _) = failure {
                        print("Unavailable \(video.id): \(status)")
                    }

                    // Only sleep on network errors, rate limits are backed off in minutes by YouTubeRateLimiter
                    if case YouTubeTranscriptKit.TranscriptError.networkError(let nwError) = error {
                        print("  backing off for 5s: \(nwError)")
                        try await Task.sleep(for: .seconds(5))
                    }

                    // What is on disk, not what the fetch was told to build on. Under
                    // --recheck-unavailable those differ, and writing the forgotten value back would
                    // rewrite content.md without the title and channel the folder already had.
                    finalInfo = infoOnDisk
                    finalTranscript = ActivityCommand.transcriptAfterFailure(failure, cached: cached)
                    availability = ActivityCommand.unavailabilityAfterFailure(failure, now: Date())
                    refusals.record(failure, cached: cached,
                                    reconfirming: ActivityCommand.isReconfirmation(availability,
                                                                                   recorded: recorded))
                }
            }

            // Now download the thumbnail after we have finalInfo. Only the largest is fetched,
            // because only the largest is ever rendered: pulling all five wrote four files nothing
            // reads, which was merely wasteful while the loop was unpaced and is hours of waiting
            // now that every miss takes its turn.
            if let thumbnail = ActivityCommand.largestThumbnail(of: finalInfo), let url = URL(string: thumbnail.url) {
                // Create assets directory only if we have a thumbnail
                try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
                let assetsPath = assetsDir.path(percentEncoded: false)

                // This runs for cached videos too, since the markdown needs the thumbnail's local
                // path whether or not this run fetched the video. Asking the cache first is what
                // keeps that free: only a miss reaches the network, and only a miss is worth waiting
                // for.
                if let cached = FileDownloader.cachedAsset(from: url, in: assetsPath) {
                    downloadedAssets[thumbnail.url] = cached
                } else {
                    // Outside the catch below, so that a cancelled run reads as cancelled rather
                    // than as a thumbnail that would not download
                    try await Task.sleep(for: .seconds(pacer.delayBeforeNextAssetFetch()))

                    // Asked of the downloader rather than of the error, because its own retry loop
                    // absorbs the throttling that clears on a second attempt and would otherwise
                    // report a clean run while the asset host was pushing back
                    let throttlesBefore = FileDownloader.rateLimitCount
                    do {
                        downloadedAssets[thumbnail.url] = try await FileDownloader.downloadFile(
                            from: url, to: assetsPath, headers: YouTubeIdentity.headers)
                    } catch {
                        print("Failed to download thumbnail: \(url)")
                    }

                    // A thumbnail that 404s belongs to a video that is gone, which says nothing
                    // about how fast this run is going. Nothing is cached for it either, so it fails
                    // again on every future run - scoring that as evidence of anything, in either
                    // direction, would be reading the same non-event forever.
                    if FileDownloader.rateLimitCount > throttlesBefore {
                        pacer.recordAssetThrottle()
                    }
                }
            }

            let videoTitle = finalInfo?.title ?? video.title ?? video.id

            // Build localized name with channel if available
            let localizedName: String
            if let channelName = finalInfo?.channelName {
                localizedName = "\(channelName) - \(videoTitle)"
            } else {
                localizedName = videoTitle
            }

            let escapedName = localizedName
            // verify title does not have newlines
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "")
            // escape for strings
                .replacingOccurrences(of: "\\", with: "\\\\")  // Must escape backslashes first
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let stringsContent = "\"\(video.id)\" = \"\(escapedName)\";"

            // Its own artifact, beside info.json rather than a stand-in for it, and written whatever
            // transcript.json holds - because this is the file that actually settles the video. It is
            // read before any fetch branch, so the next run costs zero requests even for a video
            // whose unreadable transcript.json kept a refusal from being recorded.
            //
            // Ahead of the artifacts below, because it is the only write in this loop whose
            // interruption changes the answer rather than merely losing it. Clearing it last meant a
            // run stopped between the fresh info.json and the removal left a live video holding
            // complete data next to a marker saying never ask again - and the skip branch never
            // revisits a marker, so that state was terminal. Written first, an interruption leaves
            // the video to be fetched again, which is the direction to fail in.
            switch availability {
            case .unchanged:
                break
            case .gone(let marker):
                // Only when it is news. A recheck that finds the video still gone learned nothing,
                // and restamping recordedAt would destroy the one field that scopes a batch of
                // markers to the run that wrote them - by way of the very command an operator would
                // use to investigate a batch they suspect is wrong.
                if !marker.saysTheSameAs(recorded) {
                    try encoder.encode(marker).write(to: unavailableURL, options: .atomic)
                }
            case .available:
                // The video answered, so anything recorded for it is out of date. Leaving a stale
                // marker would go on skipping a video that is back.
                do {
                    if fm.fileExists(atPath: unavailableURL.path) {
                        try fm.removeItem(at: unavailableURL)
                    }
                } catch {
                    // Worth saying out loud, because the video keeps being skipped until the file
                    // goes - but not worth abandoning the other 37,000 folders over. Naming the
                    // recovery here is the difference between a warning and an instruction.
                    print("Failed to clear unavailable.json for \(video.id): \(error)")
                    print("  delete it by hand, or re-run with --recheck-unavailable")
                }
            }

            // Write all data to disk
            // Written atomically because a run across 36,000 folders gets interrupted, and a half
            // written file here is not merely lost: transcript.json that does not decode used to be
            // indistinguishable from one that was never there, and info.json that does not decode
            // buys the video another fetch
            try encoder.encode(video.activities).write(to: activitiesURL, options: .atomic)
            if let finalTranscript = finalTranscript {
                try encoder.encode(finalTranscript).write(to: transcriptURL, options: .atomic)
            }
            if let finalInfo = finalInfo {
                try encoder.encode(finalInfo).write(to: infoURL, options: .atomic)
            }
            try stringsContent.write(to: stringsURL, atomically: true, encoding: .utf8)

            // Described against what the file will hold once the write above has run, not against
            // what this run managed to fetch. With --refetch-empty-transcripts set, a transcript
            // already recorded as empty is deliberately read as nil to force another attempt, and an
            // attempt that fails writes nothing - so the empty file is still there, and saying
            // otherwise would have the frontmatter contradict the folder it sits in.
            let renderedTranscript = ActivityCommand.renderedTranscript(
                fetched: finalTranscript ?? cached.moments,
                vttAt: vttURL,
                unavailable: ActivityCommand.isUnavailableAfterRun(availability, recorded: recorded))

            try writeMarkdown(video: video, info: finalInfo, transcript: renderedTranscript,
                              downloadedAssets: downloadedAssets, to: videoURL.path)

            // Set folder dates
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: video.firstSeen,
                .modificationDate: video.lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoURL.path)
        }

        if let refusalReport = refusals.summary {
            print(refusalReport)
        }
    }

    /// Runs one YouTube fetch at the pacer's cadence, then feeds the outcome back into it.
    ///
    /// Waiting here rather than at the top of the loop is the whole point: a cached video never
    /// reaches this method, so a resumed run does not spend seconds apiece resting between videos it
    /// already has on disk. The ban count is read off the limiter on both the success and the
    /// failure path, because backoff swallows the bans it waits out and those are precisely the ones
    /// the rest of the run should slow down for.
    private func paced<T>(_ pacer: FetchPacer, requests: Int, _ operation: () async throws -> T) async throws -> T {
        let limiter = YouTubeRateLimiter.shared

        // A limiter that has already given up throws without touching the network. Sleeping for a
        // fetch that will not happen wastes the wait, and scoring the refusal through the diff below
        // would count a ban as a clean fetch and nudge the pacer toward speeding up.
        guard !limiter.hasGivenUp else {
            return try await limiter.withBackoff(onBan: .waitItOut, operation)
        }

        try await Task.sleep(for: .seconds(pacer.delayBeforeNextFetch(requests: requests)))

        let rateLimitsBefore = limiter.rateLimitCount
        defer { pacer.recordOutcome(rateLimits: limiter.rateLimitCount - rateLimitsBefore) }

        return try await limiter.withBackoff(onBan: .waitItOut, operation)
    }

    /// The pair every artifact in a video folder is written and read with.
    ///
    /// Hoisted out of `run()` so the tests can use it rather than build a matching one. A test with
    /// its own copy passes under any self-consistent change to this configuration - and a change to
    /// the date strategy is exactly that: self-consistent, silent, and enough to orphan every marker
    /// already on disk.
    static func artifactEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func artifactDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// What transcript.json currently holds.
    ///
    /// The distinction this exists to keep is between an empty transcript and no transcript. An
    /// empty transcript.json is an answer - YouTube was asked for this video's captions and served
    /// nothing back - and reading it as "not cached yet" is what had 1,347 videos re-fetched on every
    /// run, each spending requests against a rate limit to be told the same nothing again.
    ///
    /// A file that is there but did not decode is kept apart from one that is not there at all,
    /// because a refusal is written over the second and never over the first. Collapsing them lost
    /// the contents of a half-written transcript.json and marked the video caption-free forever, for
    /// a video whose transcript had never been read.
    enum CachedTranscript {
        case missing
        case unreadable
        case transcript([TranscriptMoment])

        /// What is on disk, or nil where nothing readable is.
        var moments: [TranscriptMoment]? {
            guard case .transcript(let moments) = self else { return nil }
            return moments
        }
    }

    static func cachedTranscript(at url: URL, decoder: JSONDecoder) -> CachedTranscript {
        guard let data = try? Data(contentsOf: url) else { return .missing }
        guard let loaded = try? decoder.decode([TranscriptMoment].self, from: data) else { return .unreadable }
        return .transcript(loaded)
    }

    /// What the fetch below should treat as already known.
    ///
    /// Normally that is whatever decoded. Under --refetch-empty-transcripts a recorded refusal is
    /// deliberately forgotten, so the video goes back down a fetch branch and YouTube is asked
    /// again - the way back for the day YouTube starts serving the tracks it refuses now, without
    /// anyone having to find and delete thousands of four-byte files by hand.
    static func transcriptToBuildOn(cached: CachedTranscript, refetchEmpty: Bool) -> [TranscriptMoment]? {
        guard let moments = cached.moments else { return nil }
        return refetchEmpty && moments.isEmpty ? nil : moments
    }

    /// Why a transcript fetch came back without one.
    enum FetchFailure {
        /// `noCaptionData`: YouTube's player response listed no caption tracks for this video.
        case noTracksListed
        /// `noTranscriptData`: tracks were listed, and fetching them produced nothing.
        case listedTracksWereEmpty
        /// `videoUnavailable` carrying a status this tool has established is permanent - not every
        /// unavailable video, and `permanentlyUnavailableStatuses` is where that list is argued.
        case permanentlyUnavailable(status: String, reason: String?)
        /// Anything else - a ban, a dropped connection, HTML that did not parse.
        case unresolved
    }

    /// The playability statuses this tool is willing to write a video off for.
    ///
    /// An allowlist rather than a denylist, because the two mistakes do not cost the same. Retrying a
    /// video that is permanently gone spends requests. Filing a video permanently that is merely
    /// unreachable right now drops it from the corpus and leaves a marker saying not to ask again -
    /// and nothing later notices, because the whole effect of the marker is that no run looks.
    ///
    /// `ERROR` is a deleted video and `UNPLAYABLE` is a members-only one. Both are captured in the
    /// kit's fixtures and both are established there as permanent.
    ///
    /// `LOGIN_REQUIRED` is deliberately absent, and it is the reason this is a list at all rather
    /// than "any videoUnavailable". YouTube sends it for a private video, which is permanent, and
    /// also for its "Sign in to confirm you're not a bot" wall, which is a soft ban and about as
    /// transient as anything gets. That wall arrives as a 200 on a page the kit's captcha check
    /// cannot see, since it only matches the /sorry redirect, so nothing upstream catches it first.
    /// Treating every `videoUnavailable` as permanent would write off every video fetched during a
    /// ban - thousands of live videos, in one run, each with a file beside it saying do not ask
    /// again. The reason prose that would tell the two apart has never been captured, so nothing
    /// here guesses at it.
    ///
    /// Everything unrecognised falls through to `.unresolved` and is retried, which is exactly what
    /// happens today and is the safe direction to be wrong in. `LIVE_STREAM_OFFLINE`, for one, is a
    /// stream that has not started yet.
    ///
    /// Matched verbatim and case-sensitively against YouTube's own code, which the kit passes through
    /// unmapped. A status differing even in case is one this tool has not seen before.
    static let permanentlyUnavailableStatuses: Set<String> = ["ERROR", "UNPLAYABLE"]

    static func classifyFailure(_ error: Error) -> FetchFailure {
        switch error {
        case YouTubeTranscriptKit.TranscriptError.noCaptionData:
            return .noTracksListed
        case YouTubeTranscriptKit.TranscriptError.noTranscriptData:
            return .listedTracksWereEmpty
        case YouTubeTranscriptKit.TranscriptError.videoUnavailable(let status, let reason)
                where permanentlyUnavailableStatuses.contains(status):
            return .permanentlyUnavailable(status: status, reason: reason)
        default:
            return .unresolved
        }
    }

    /// What a failed transcript fetch leaves on disk.
    ///
    /// Both refusals are recorded as an empty transcript, and neither is recorded because the video
    /// is known to have no captions. `noTracksListed` does mean that, as far as YouTube's player
    /// response is concerned. `listedTracksWereEmpty` means the opposite: YouTube named caption
    /// tracks and then served nothing when they were fetched, which is the zero-byte answer this
    /// whole change exists around - many of those videos demonstrably do have captions, since yt-dlp
    /// pulled 3,183 of them through a client the web endpoint does not serve.
    ///
    /// What makes recording both right is not that the captions are gone, but that asking again over
    /// the web changes nothing and costs two requests against a rate limit. That holds because the
    /// kit rules out a ban, a timeout or a 5xx before either error can be constructed, so neither
    /// describes a bad moment. The one that could start working again is `listedTracksWereEmpty`, and
    /// --refetch-empty-transcripts is what clears it when it does.
    ///
    /// A permanently unavailable video is the one that looks like it belongs here and does not. It
    /// passes the test above - there is no watchable page left, so asking again changes nothing - but
    /// an empty transcript.json is not only a note that asking is pointless, it is a record of what
    /// YouTube answered about captions. Nothing was ever asked: the kit throws `videoUnavailable`
    /// from the info parse, before a single caption track is fetched. Writing `[]` there would put a
    /// false answer in the corpus, and a specific one - content.md renders it as
    /// `transcriptSource: none`, which is documented as the population worth pointing yt-dlp at, and
    /// yt-dlp cannot fetch a deleted video either.
    ///
    /// So the cache is left exactly as it was and unavailable.json carries the fact instead. That is
    /// also what makes the marker recoverable: deleting the markers really does undo the write-off,
    /// rather than leaving behind an answer no later run will ever revisit. Only the statuses
    /// established as permanent arrive as this failure at all - `LOGIN_REQUIRED` during a ban is
    /// classified `.unresolved`, and leaves the cache untouched for a different reason.
    ///
    /// Every other failure leaves the cache exactly as it was: a refusal recorded from a dropped
    /// connection would be a lie with no expiry. So does a file that did not decode - overwriting
    /// that would destroy a transcript rather than record the absence of one.
    static func transcriptAfterFailure(_ failure: FetchFailure, cached: CachedTranscript) -> [TranscriptMoment]? {
        switch (failure, cached) {
        case (.unresolved, _), (.permanentlyUnavailable, _), (_, .unreadable):
            return cached.moments
        case (_, .missing):
            return []
        case (_, .transcript(let moments)):
            return moments
        }
    }

    /// What `unavailable.json` records: YouTube's own verdict on a video, and when it was taken.
    ///
    /// Its own artifact rather than a synthesized `info.json`, deliberately. A `VideoInfo` built out
    /// of a failed fetch would be indistinguishable on disk from one that was really fetched, and the
    /// render path would then present invented data - a title, a channel, a duration nobody ever
    /// received - as though YouTube had served it. This file is written by the thing that learned the
    /// fact and claims nothing past it.
    ///
    /// `status` is kept verbatim and unmapped because the allowlist that decided this file was worth
    /// writing may turn out to be wrong. YouTube's own code on disk means a mistake can be found and
    /// undone with a grep, rather than by re-fetching 37,000 videos to find out which ones were
    /// written off for what.
    struct UnavailableVideo: Codable, Equatable {
        /// YouTube's playability status, verbatim - "ERROR" for a deleted video, "UNPLAYABLE" for a
        /// members-only one.
        let status: String
        /// YouTube's prose, for whoever opens the folder. Absent for the statuses that ship without one.
        let reason: String?
        /// When the verdict this file records was first written down. Runs that skip the video never
        /// touch it, and neither does a --recheck-unavailable run that finds the same status again -
        /// that is what `saysTheSameAs` is for, so a batch of markers stays scoped to the run that
        /// wrote them. Only a status that changed rewrites the file, and the date with it, because
        /// then it is a different verdict. Recorded rather than derived because a future expiry
        /// policy would need it and no later run can learn it after the fact.
        let recordedAt: Date

        /// The failure this marker stands for, so a run that skips the video reaches the same
        /// decisions about it as the run that recorded it.
        var asFailure: FetchFailure {
            return .permanentlyUnavailable(status: status, reason: reason)
        }

        /// Whether this records the same verdict as one already on disk.
        ///
        /// The status, and only the status. The date is excluded because it is what tells a
        /// re-confirmation from something new, so comparing it would make every marker look new and
        /// rewrite the one field that answers the question. The reason is excluded because it is
        /// YouTube's prose: it gets reworded, localized, and renamed as membership tiers are renamed,
        /// and none of that is a change in the verdict. Comparing it would let a copy edit on
        /// YouTube's side restamp recordedAt across the whole corpus and report every marker as newly
        /// written off - the one shape this tally reserves for a misclassified ban.
        ///
        /// Consistent with `classifyFailure`, which decides permanence from the status alone. What
        /// counts as the same verdict has to be what the verdict was made from.
        func saysTheSameAs(_ other: UnavailableVideo?) -> Bool {
            guard let other = other else { return false }
            return status == other.status
        }
    }

    /// What a run learned about whether a video can be fetched at all.
    ///
    /// Three states rather than two, and the third is the one doing the work. "Nothing was learned"
    /// is the answer for most failures and has to be told apart from "this video is fine": a ban, a
    /// timeout or a 5xx says nothing about the video, so it must neither file one as gone nor clear
    /// a marker already recorded for one.
    enum UnavailabilityOutcome: Equatable {
        /// Nothing was asked, or what came back says nothing about availability. Disk is left alone.
        case unchanged
        /// YouTube answered with a status this tool treats as permanent. The marker gets written.
        case gone(UnavailableVideo)
        /// The video answered. Anything recorded for it is stale and gets removed.
        case available
    }

    /// What a failed fetch means for `unavailable.json`.
    ///
    /// Only an established-permanent status writes a marker; everything else returns `.unchanged`
    /// rather than `.available`. That is the distinction the file turns on. Reading "this fetch did
    /// not prove the video gone" as "this video is fine" would delete markers all through a ban and
    /// hand the next run back the whole population this exists to drain.
    static func unavailabilityAfterFailure(_ failure: FetchFailure, now: Date) -> UnavailabilityOutcome {
        guard case .permanentlyUnavailable(let status, let reason) = failure else { return .unchanged }
        return .gone(UnavailableVideo(status: status, reason: reason, recordedAt: now))
    }

    /// Whether this outcome only re-confirms what is already recorded.
    ///
    /// The same test the marker write uses, so the count and the file cannot disagree about whether
    /// the run learned anything. A recheck that finds thousands of videos still gone must not report
    /// thousands of write-offs: that is the shape a misclassified ban would take, and a flag whose
    /// whole purpose is to look for videos that came back would raise it on every use.
    static func isReconfirmation(_ outcome: UnavailabilityOutcome, recorded: UnavailableVideo?) -> Bool {
        guard case .gone(let marker) = outcome else { return false }
        return marker.saysTheSameAs(recorded)
    }

    /// What `unavailable.json` currently holds, or nil where nothing readable is there.
    ///
    /// A file that does not decode reads the same as one that was never written, which is the
    /// opposite of how `cachedTranscript` treats transcript.json - and the asymmetry is the point. A
    /// half-written transcript.json may hold words no run will ever fetch again, so it is never
    /// overwritten. This file holds nothing that cannot be learned again by asking, so the worst a
    /// corrupt one costs is the fetch that rewrites it.
    static func recordedUnavailability(at url: URL, decoder: JSONDecoder) -> UnavailableVideo? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(UnavailableVideo.self, from: data)
    }

    /// What the fetch should treat as already known about the video itself.
    ///
    /// Normally whatever info.json holds. Under --recheck-unavailable a video that has a marker
    /// deliberately forgets it, which is the same move `transcriptToBuildOn` makes for a recorded
    /// refusal and is made for the same reason: forgetting the marker alone only removes the
    /// short-circuit, and the branches below still key off what is cached. Without this, a marked
    /// video holding both info.json and transcript.json would never reach a fetch, so its marker
    /// could never be re-confirmed or cleared - a recorded verdict with no way to appeal it, which is
    /// exactly what the flag exists to prevent.
    ///
    /// Scoped to videos that have a marker. Since a written-off video normally has no transcript.json
    /// either, forgetting the info puts it on the combined fetch at two requests; a folder that does
    /// still hold a transcript costs one. Nothing at all is spent on the rest of the corpus.
    static func infoToBuildOn(cached: VideoInfo?, recorded: UnavailableVideo?, recheck: Bool) -> VideoInfo? {
        return recheck && recorded != nil ? nil : cached
    }

    /// What the fetch should treat as already settled.
    ///
    /// Normally whatever was recorded. Under --recheck-unavailable the marker is deliberately
    /// forgotten so the video goes back down a fetch branch and YouTube is asked again - the way back
    /// for a video that gets un-privated or restored, without anyone having to find and delete
    /// markers by hand across 37,000 folders.
    static func unavailabilityToTrust(recorded: UnavailableVideo?, recheck: Bool) -> UnavailableVideo? {
        return recheck ? nil : recorded
    }

    /// Tallies the refusals a run writes down, so that a corpus-wide break is visible while it is
    /// still cheap to undo.
    ///
    /// The kit reports `noCaptionData` both when a video genuinely has no captions and when a
    /// player-response blob fails to decode - it says so itself, because a video without captions
    /// reaches the same place as a missing key and the two cannot be told apart. Now that a run
    /// writes those refusals down, a schema change on YouTube's side would mark every video
    /// caption-free on one run and then be invisible on every run after it, because nothing would
    /// ever fetch again. A count does not disambiguate them, but a run that records 30,000 reads
    /// very differently from one that records 40.
    ///
    /// The ambiguity is documented upstream rather than fixed, and cannot be fixed there: a video
    /// without captions and a malformed blob both arrive as a missing key. So the trap re-arms on
    /// every YouTube schema change and this is the only thing watching for it, which makes it part
    /// of what keeps the corpus correct rather than decoration on the progress output.
    ///
    /// The same argument now covers a second population, with more force. A video recorded as
    /// permanently unavailable is written off on this tool's own reading of which YouTube statuses
    /// are permanent, and a misreading there does not fail loudly - it quietly stops asking, and
    /// keeps stopping, because the marker's whole effect is that no later run looks. What that
    /// mistake would look like is a run writing off thousands of videos where the last wrote off a
    /// dozen: a soft ban misread as a corpus of dead videos. Counting it here is what surfaces that
    /// while the markers are still cheap to delete.
    struct RefusalTally {
        /// Which kind of refusal was recorded, or why one was not.
        struct Counts {
            var noTracksListed = 0
            var listedTracksWereEmpty = 0
            var duringCombinedFetch = 0
            var blockedByUnreadableFile = 0
            var permanentlyUnavailable = 0
            var reconfirmedUnavailable = 0
            var skippedAsUnavailable = 0

            /// Refusals that reached disk. Deliberately does not include the ones held back, since
            /// the headline below says "recorded" and a run that wrote nothing at all must not read
            /// as one that wrote five.
            ///
            /// Nor does it include the videos written off, which record nothing in transcript.json
            /// at all. Each count is a tripwire for a different break - a caption parser that
            /// stopped working, an allowlist that started writing off live videos - and folding
            /// either into the other would blind both.
            var recorded: Int {
                return noTracksListed + listedTracksWereEmpty + duringCombinedFetch
            }

            var total: Int {
                return recorded + blockedByUnreadableFile + permanentlyUnavailable
                    + reconfirmedUnavailable + skippedAsUnavailable
            }

            static func - (lhs: Counts, rhs: Counts) -> Counts {
                return Counts(noTracksListed: lhs.noTracksListed - rhs.noTracksListed,
                              listedTracksWereEmpty: lhs.listedTracksWereEmpty - rhs.listedTracksWereEmpty,
                              duringCombinedFetch: lhs.duringCombinedFetch - rhs.duringCombinedFetch,
                              blockedByUnreadableFile: lhs.blockedByUnreadableFile - rhs.blockedByUnreadableFile,
                              permanentlyUnavailable: lhs.permanentlyUnavailable - rhs.permanentlyUnavailable,
                              reconfirmedUnavailable: lhs.reconfirmedUnavailable - rhs.reconfirmedUnavailable,
                              skippedAsUnavailable: lhs.skippedAsUnavailable - rhs.skippedAsUnavailable)
            }

            func summary(_ qualifier: String) -> String? {
                guard total > 0 else { return nil }

                let heldBack = blockedByUnreadableFile > 0
                    ? "; \(blockedByUnreadableFile) more held back by a file that did not decode, and so asked again every run"
                    : ""

                // Collapsed to a phrase when there were none. Once markers exist, nearly every block
                // skips a video and so has something to report, and spelling out four zeroes each
                // time buries the number this whole tally exists to make jump out.
                let refusals = (recorded + blockedByUnreadableFile) > 0
                    ? "recorded \(recorded) transcript refusals\(qualifier): \(noTracksListed) with no tracks listed, "
                        + "\(listedTracksWereEmpty) whose tracks came back empty, "
                        + "\(duringCombinedFetch) during a combined fetch"
                        + heldBack
                    : "recorded no transcript refusals\(qualifier)"

                let writtenOff = permanentlyUnavailable > 0
                    ? "; \(permanentlyUnavailable) newly recorded as permanently unavailable"
                    : ""

                let reconfirmed = reconfirmedUnavailable > 0
                    ? "; \(reconfirmedUnavailable) confirmed still unavailable"
                    : ""

                let skipped = skippedAsUnavailable > 0
                    ? "; \(skippedAsUnavailable) skipped as already recorded unavailable"
                    : ""

                return refusals + writtenOff + reconfirmed + skipped
            }
        }

        private(set) var counts = Counts()

        /// What the last periodic report already said, so the next one can describe its own block.
        private var reported = Counts()

        /// Derives the same decision `transcriptAfterFailure` makes, from the same two inputs, so
        /// that what is counted cannot drift from what is written.
        ///
        /// That rule holds for the refusals, which are the only thing transcript.json records. A
        /// permanently unavailable video is counted against unavailable.json instead - it is written
        /// whatever the transcript cache holds, so this method takes `reconfirming` from the same
        /// test the marker write uses rather than deriving it from `cached`.
        ///
        /// Undefaulted on purpose. A defaulted flag is the one way a future call site could quietly
        /// file a re-confirmation as news and inflate the count this tally exists to make alarming.
        mutating func record(_ failure: FetchFailure, cached: CachedTranscript, reconfirming: Bool) {
            guard !isUnresolved(failure) else { return }

            // Counted ahead of the unreadable check, and deliberately not subject to it. What settles
            // a permanently unavailable video is unavailable.json, which gets written whatever
            // transcript.json holds - so unlike a refusal, this one is not stranded by a file nobody
            // could read, and filing it with the population that is would misreport both.
            if case .permanentlyUnavailable = failure {
                if reconfirming {
                    counts.reconfirmedUnavailable += 1
                } else {
                    counts.permanentlyUnavailable += 1
                }
                return
            }

            // A refusal that lands on a file which did not decode is deliberately not written, so
            // this video will be asked about again on every run from here on. Counted apart, because
            // that set is the only one here that does not settle by itself - and the silence around
            // it was the whole cost of choosing not to overwrite a file nobody could read.
            if case .unreadable = cached {
                counts.blockedByUnreadableFile += 1
                return
            }

            switch failure {
            case .noTracksListed: counts.noTracksListed += 1
            case .listedTracksWereEmpty: counts.listedTracksWereEmpty += 1
            case .permanentlyUnavailable: break  // returned above, before the unreadable check
            case .unresolved: break
            }
        }

        /// The combined fetch swallows both refusals inside the kit and hands back a nil transcript,
        /// so which one it was cannot be recovered here.
        ///
        /// Takes the cache for the same reason `record` does: this refusal is not written over a file
        /// that failed to decode either, and counting it as recorded would file a stranded video
        /// under the bucket that says it settled.
        mutating func recordCombinedFetch(cached: CachedTranscript) {
            if case .unreadable = cached {
                counts.blockedByUnreadableFile += 1
                return
            }
            counts.duringCombinedFetch += 1
        }

        /// A video this run never asked about, because an earlier run recorded that YouTube will not
        /// serve it.
        ///
        /// Counted apart from the videos recorded this run, and the separation is what makes the
        /// other count usable. Newly-recorded is the tripwire; once a bad run has written thousands
        /// of markers, every run after it skips those same thousands, and folding the two together
        /// would bury each day's spike under a permanent baseline. Reported because it is also the
        /// evidence the queue is draining rather than silently doing nothing.
        mutating func recordSkippedAsUnavailable() {
            counts.skippedAsUnavailable += 1
        }

        /// What has been recorded since this was last asked.
        ///
        /// A block rather than a running total, because a break part way through 36,000 videos reads
        /// as 740, 840, 940 in a total - indistinguishable from ordinary accumulation - and as
        /// 4, 3, 4, 100, 100, 100 in a block.
        mutating func takeBlockSinceLastReport() -> String? {
            let block = counts - reported
            reported = counts
            return block.summary(" since the last report")
        }

        var summary: String? {
            return counts.summary("")
        }

        private func isUnresolved(_ failure: FetchFailure) -> Bool {
            if case .unresolved = failure { return true }
            return false
        }
    }

    /// Picks what content.md shows for its transcript, and what it says about where that came from.
    ///
    /// content.md is rewritten from scratch every run, which is what lets it read transcript.vtt
    /// here at render time and show the words yt-dlp pulled for videos whose captions the web
    /// endpoint will not serve. Nothing derived from that file is written back: transcript.json
    /// stays hunch's own fetch, transcript.vtt stays yt-dlp's, and the frontmatter names which of
    /// them the reader is looking at rather than leaving the two indistinguishable.
    ///
    /// hunch's own fetch wins when it has words in it, since that is the file this tool is
    /// responsible for. When neither file has anything the frontmatter still says so, and says which
    /// kind of nothing it is: a video YouTube has already answered with silence reads differently
    /// from one no run has managed to ask about, and it is the first of those that yt-dlp is worth
    /// pointing at.
    ///
    /// A video that is gone is a third kind, and is checked after the VTT rather than before it: a
    /// transcript yt-dlp pulled before the video was deleted is still the words this video had, and
    /// is worth rendering. Only when there is nothing to show does the absence get named.
    static func renderedTranscript(fetched: [TranscriptMoment]?, vttAt vttURL: URL,
                                   unavailable: Bool) -> RenderedTranscript {
        if let fetched = fetched, !fetched.isEmpty {
            return RenderedTranscript(lines: fetched.map { TranscriptLine(start: $0.start, text: $0.text) },
                                      source: .fetch)
        }

        if let lines = VTTTranscript.load(from: vttURL), !lines.isEmpty {
            return RenderedTranscript(lines: lines, source: .ytDLP)
        }

        if unavailable {
            return RenderedTranscript(lines: [], source: .videoUnavailable)
        }

        // An empty array on disk means YouTube answered; nil means no run ever got that far
        return RenderedTranscript(lines: [], source: fetched == nil ? .unfetched : .knownEmpty)
    }

    /// Whether `unavailable.json` will be there once this iteration's writes have run.
    ///
    /// Described against the file rather than against the attempt, for the same reason the transcript
    /// beside it is: content.md is rewritten every run and has to describe the folder it sits in. A
    /// failure that learned nothing leaves whatever was already recorded standing.
    ///
    /// One path can still disagree with disk: a removal that failed leaves the marker there while
    /// this reports the video is fine. That is the stale marker's problem rather than this one's, and
    /// the loop prints it along with how to clear it.
    static func isUnavailableAfterRun(_ outcome: UnavailabilityOutcome, recorded: UnavailableVideo?) -> Bool {
        switch outcome {
        case .gone: return true
        case .available: return false
        case .unchanged: return recorded != nil
        }
    }

    /// The one thumbnail a video's markdown renders, so the download and the render cannot disagree
    /// about which one that is. Downloading a thumbnail the renderer will not name buys nothing but
    /// another request to the asset host.
    private static func largestThumbnail(of info: VideoInfo?) -> VideoThumbnail? {
        return info?.thumbnails?.sorted(by: { $0.width * $0.height > $1.width * $1.height }).first
    }

    private func parseActivities(from url: URL) async throws -> [VideoData] {
        // Parse activity file
        let activities = try await YouTubeTranscriptKit.getActivity(fileURL: url)

        // Filter and group video activities by ID
        var videoActivities: [String: [Activity]] = [:]

        for activity in activities {
            if case .video(let id, _) = activity.link {
                videoActivities[id, default: []].append(activity)
            }
        }

        // Convert to array of VideoData
        let videos = videoActivities.map { id, activities in
            VideoData(id: id, activities: activities)
        }

        // Sort by most recent activity
        return videos.sorted { $0.lastSeen > $1.lastSeen }
    }

    private func writeMarkdown(video: VideoData, info: VideoInfo?, transcript: RenderedTranscript,
                               downloadedAssets: [String: FileDownloader.DownloadedAsset], to directory: String) throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = .utc
        dateFormatter.formatOptions = [.withInternetDateTime]

        let title = info?.title ?? video.title ?? video.id
        let videoUrl = info?.videoURL?.absoluteString ?? "https://www.youtube.com/watch?v=\(video.id)"

        // Format channel info
        let channelUrl = info?.channelId.map { "https://www.youtube.com/channel/\($0)" }
        let channelMention = info?.channelId.map { "@\($0)" }

        var markdown = """
            ---
            title: "\(title)"
            videoId: \(video.id)
            firstSeen: \(dateFormatter.string(from: video.firstSeen))
            lastSeen: \(dateFormatter.string(from: video.lastSeen))
            \(info?.channelId.map { "channelId: \($0)" } ?? "")
            \(info?.channelName.map { "channel: \($0)" } ?? "")
            \(channelMention.map { "channelMention: \($0)" } ?? "")
            \(channelUrl.map { "channelURL: \($0)" } ?? "")
            \(info?.publishedAt.map { "published: \(dateFormatter.string(from: $0))" } ?? "")
            \(info?.uploadedAt.map { "uploaded: \(dateFormatter.string(from: $0))" } ?? "")
            \(info?.viewCount.map { "views: \($0)" } ?? "")
            \(info?.duration.map { seconds -> String in
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                let remainingSeconds = seconds % 60
                if hours > 0 {
                    return "duration: \(hours):\(String(format: "%02d:%02d", minutes, remainingSeconds))"
                } else {
                    return "duration: \(String(format: "%d:%02d", minutes, remainingSeconds))"
                }
            } ?? "")
            \(info?.category.map { "category: \($0)" } ?? "")
            \(info?.isLive.map { "isLive: \($0)" } ?? "")
            transcriptSource: \(transcript.source.rawValue)
            ---

            """

        // Create renderer with our downloaded assets
        let renderer = MarkdownRenderer(level: 0, ignoreColor: false, ignoreUnderline: false, downloadedAssets: downloadedAssets)

        // Add largest thumbnail if available
        if let thumb = ActivityCommand.largestThumbnail(of: info) {
            let imageBlock = Block(
                object: "block",
                id: video.id,
                parent: nil,
                type: .image,
                createdTime: dateFormatter.string(from: video.firstSeen),
                createdBy: PartialUser(object: "user", id: video.id),
                lastEditedTime: dateFormatter.string(from: video.lastSeen),
                lastEditedBy: PartialUser(object: "user", id: video.id),
                archived: false,
                inTrash: false,
                hasChildren: false,
                blockTypeObject: .image(ImageBlock(
                    image: FileBlock(
                        caption: nil,
                        type: .external(FileBlock.FileType.External(url: thumb.url))
                    )
                ))
            )
            markdown += try renderer.render([imageBlock])
        }

        // Add video title link
        markdown += "[\(title)](\(videoUrl))"

        // Add channel link if we have both name and ID
        if let channelName = info?.channelName, let channelId = info?.channelId {
            markdown += " by [\(channelName)](https://www.youtube.com/channel/\(channelId))"
        }

        if let description = info?.description {
            markdown += "\n\n## Description\n\n\(description)\n"
        }

        if !transcript.lines.isEmpty {
            markdown += "\n## Transcript\n\n"
            let hasHours = (info?.duration ?? 0) > 3600
            var lastTimeBlock = -1
            for moment in transcript.lines {
                let seconds = Int(moment.start)
                let timeBlock = seconds / 1800  // 1800 seconds = 30 minutes
                if timeBlock > lastTimeBlock && lastTimeBlock >= 0 {
                    // Add extra newline between 30-minute blocks
                    // This helps Typora markdown parsing
                    markdown += "\n"
                }
                lastTimeBlock = timeBlock

                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                let remainingSeconds = seconds % 60
                let timestamp = hasHours ?
                    String(format: "[%d:%02d:%02d]", hours, minutes, remainingSeconds) :
                    String(format: "[%d:%02d]", minutes, remainingSeconds)
                let timestampURL = "\(videoUrl)&t=\(seconds)"
                let transcriptText = moment.text.replacingOccurrences(of: "\n", with: " ")
                markdown += "[\(timestamp)](\(timestampURL)) \(transcriptText)\n"
            }
        }

        let filePath = (directory as NSString).appendingPathComponent("content.md")
        try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
