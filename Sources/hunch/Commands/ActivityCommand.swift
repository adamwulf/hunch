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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

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
            let info: VideoInfo? = {
                guard let data = try? Data(contentsOf: infoURL) else { return nil }
                return try? decoder.decode(VideoInfo.self, from: data)
            }()

            // What is on disk, and then what the fetch below should make of it. The two are kept
            // apart because the flag only changes what gets asked for, never what gets believed
            // about the file: the render still has to describe the file that is actually there.
            let cached = ActivityCommand.cachedTranscript(at: transcriptURL, decoder: decoder)
            let transcript = ActivityCommand.transcriptToBuildOn(cached: cached, refetchEmpty: refetchEmptyTranscripts)

            // Process data with exponential backoff on failure
            let finalInfo: VideoInfo?
            let finalTranscript: [TranscriptMoment]?
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
                case (nil, .some(let cachedTranscript)):
                    print("Fetching info: \(video.id)")
                    let fetched = try await paced(pacer, requests: 1) {
                        try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: false)
                    }
                    finalInfo = fetched.withoutTranscript()
                    finalTranscript = cachedTranscript
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
                case (.some(let cachedInfo), .some(let cachedTranscript)):
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

                // Only sleep on network errors, rate limits are backed off in minutes by YouTubeRateLimiter
                if case YouTubeTranscriptKit.TranscriptError.networkError(let nwError) = error {
                    print("  backing off for 5s: \(nwError)")
                    try await Task.sleep(for: .seconds(5))
                }

                finalInfo = info
                refusals.record(failure, cached: cached)
                finalTranscript = ActivityCommand.transcriptAfterFailure(failure, cached: cached)
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
            let renderedTranscript = ActivityCommand.renderedTranscript(fetched: finalTranscript ?? cached.moments,
                                                                        vttAt: vttURL)

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
        /// Anything else - a ban, a dropped connection, HTML that did not parse.
        case unresolved
    }

    static func classifyFailure(_ error: Error) -> FetchFailure {
        switch error {
        case YouTubeTranscriptKit.TranscriptError.noCaptionData:
            return .noTracksListed
        case YouTubeTranscriptKit.TranscriptError.noTranscriptData:
            return .listedTracksWereEmpty
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
    /// Every other failure leaves the cache exactly as it was: a refusal recorded from a dropped
    /// connection would be a lie with no expiry. So does a file that did not decode - overwriting
    /// that would destroy a transcript rather than record the absence of one.
    static func transcriptAfterFailure(_ failure: FetchFailure, cached: CachedTranscript) -> [TranscriptMoment]? {
        switch (failure, cached) {
        case (.unresolved, _), (_, .unreadable):
            return cached.moments
        case (_, .missing):
            return []
        case (_, .transcript(let moments)):
            return moments
        }
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
    struct RefusalTally {
        /// Which kind of refusal was recorded, or why one was not.
        struct Counts {
            var noTracksListed = 0
            var listedTracksWereEmpty = 0
            var duringCombinedFetch = 0
            var blockedByUnreadableFile = 0

            /// Refusals that reached disk. Deliberately does not include the ones held back, since
            /// the headline below says "recorded" and a run that wrote nothing at all must not read
            /// as one that wrote five.
            var recorded: Int {
                return noTracksListed + listedTracksWereEmpty + duringCombinedFetch
            }

            var total: Int {
                return recorded + blockedByUnreadableFile
            }

            static func - (lhs: Counts, rhs: Counts) -> Counts {
                return Counts(noTracksListed: lhs.noTracksListed - rhs.noTracksListed,
                              listedTracksWereEmpty: lhs.listedTracksWereEmpty - rhs.listedTracksWereEmpty,
                              duringCombinedFetch: lhs.duringCombinedFetch - rhs.duringCombinedFetch,
                              blockedByUnreadableFile: lhs.blockedByUnreadableFile - rhs.blockedByUnreadableFile)
            }

            func summary(_ qualifier: String) -> String? {
                guard total > 0 else { return nil }

                let heldBack = blockedByUnreadableFile > 0
                    ? "; \(blockedByUnreadableFile) more held back by a file that did not decode, and so asked again every run"
                    : ""

                return "recorded \(recorded) transcript refusals\(qualifier): \(noTracksListed) with no tracks listed, "
                    + "\(listedTracksWereEmpty) whose tracks came back empty, "
                    + "\(duringCombinedFetch) during a combined fetch"
                    + heldBack
            }
        }

        private(set) var counts = Counts()

        /// What the last periodic report already said, so the next one can describe its own block.
        private var reported = Counts()

        /// Derives the same decision `transcriptAfterFailure` makes, from the same two inputs, so
        /// that what is counted cannot drift from what is written.
        mutating func record(_ failure: FetchFailure, cached: CachedTranscript) {
            guard !isUnresolved(failure) else { return }

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
    static func renderedTranscript(fetched: [TranscriptMoment]?, vttAt vttURL: URL) -> RenderedTranscript {
        if let fetched = fetched, !fetched.isEmpty {
            return RenderedTranscript(lines: fetched.map { TranscriptLine(start: $0.start, text: $0.text) },
                                      source: .fetch)
        }

        if let lines = VTTTranscript.load(from: vttURL), !lines.isEmpty {
            return RenderedTranscript(lines: lines, source: .ytDLP)
        }

        // An empty array on disk means YouTube answered; nil means no run ever got that far
        return RenderedTranscript(lines: [], source: fetched == nil ? .unfetched : .knownEmpty)
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
