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
                    finalTranscript = fetched.transcript
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
                // The two refusals below are answers rather than failures, and the run records them
                // just above as such, so printing them as errors would put a line on screen for
                // every video YouTube has no captions for
                switch error {
                case YouTubeTranscriptKit.TranscriptError.noCaptionData,
                     YouTubeTranscriptKit.TranscriptError.noTranscriptData:
                    break
                default:
                    print("Error processing \(video.id): \(error)")
                }

                // Only sleep on network errors, rate limits are backed off in minutes by YouTubeRateLimiter
                if case YouTubeTranscriptKit.TranscriptError.networkError(let nwError) = error {
                    print("  backing off for 5s: \(nwError)")
                    try await Task.sleep(for: .seconds(5))
                }

                finalInfo = info
                finalTranscript = ActivityCommand.transcriptAfterFailure(error, cached: cached)
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
            try encoder.encode(video.activities).write(to: activitiesURL)
            if let finalTranscript = finalTranscript {
                try encoder.encode(finalTranscript).write(to: transcriptURL)
            }
            if let finalInfo = finalInfo {
                try encoder.encode(finalInfo).write(to: infoURL)
            }
            try stringsContent.write(to: stringsURL, atomically: true, encoding: .utf8)

            // Described against what the file will hold once the write above has run, not against
            // what this run managed to fetch. With --refetch-empty-transcripts set, a transcript
            // already recorded as empty is deliberately read as nil to force another attempt, and an
            // attempt that fails writes nothing - so the empty file is still there, and saying
            // otherwise would have the frontmatter contradict the folder it sits in.
            let renderedTranscript = ActivityCommand.renderedTranscript(fetched: finalTranscript ?? cached, vttAt: vttURL)

            try writeMarkdown(video: video, info: finalInfo, transcript: renderedTranscript,
                              downloadedAssets: downloadedAssets, to: videoURL.path)

            // Set folder dates
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: video.firstSeen,
                .modificationDate: video.lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoURL.path)
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

    /// What transcript.json currently holds, with an empty file preserved as an empty array.
    ///
    /// The distinction this function exists to keep is between an empty array and nil. An empty
    /// transcript.json is an answer - YouTube was asked for this video's captions and served nothing
    /// back - and collapsing it to nil reads as "not cached yet", which is what had 1,347 videos
    /// re-fetched on every run, each spending requests against a rate limit to be told the same
    /// nothing again. nil is reserved for a file that is absent or unreadable.
    static func cachedTranscript(at url: URL, decoder: JSONDecoder) -> [TranscriptMoment]? {
        guard
            let data = try? Data(contentsOf: url),
            let loaded = try? decoder.decode([TranscriptMoment].self, from: data)
        else { return nil }
        return loaded
    }

    /// What the fetch below should treat as already known.
    ///
    /// Normally that is whatever is on disk. Under --refetch-empty-transcripts a recorded refusal is
    /// deliberately forgotten, so the video goes back down a fetch branch and YouTube is asked
    /// again - the way back for the day YouTube starts serving the tracks it refuses now, without
    /// anyone having to find and delete thousands of four-byte files by hand.
    static func transcriptToBuildOn(cached: [TranscriptMoment]?, refetchEmpty: Bool) -> [TranscriptMoment]? {
        guard refetchEmpty, cached?.isEmpty == true else { return cached }
        return nil
    }

    /// What a failed transcript fetch leaves on disk.
    ///
    /// Two of the kit's errors are answers rather than failures: `noCaptionData` means the video has
    /// no caption tracks at all, and `noTranscriptData` means every track it does have came back
    /// with nothing in it. The kit rules out a ban or a dropped connection before either can be
    /// thrown, so both describe the video rather than the moment, and a retry finds the same thing.
    /// Recording them as an empty transcript is what stops this from being asked again forever - it
    /// is the same judgement the empty files already on disk represent, made when the refusal
    /// happens rather than only when an older run happened to leave a file behind.
    ///
    /// Everything else - a ban, a dropped connection, HTML that did not parse - says nothing about
    /// whether the video has captions, so the cache is left exactly as it was and the next run asks
    /// again. And if YouTube ever restores these tracks corpus-wide, the recorded refusals are what
    /// --refetch-empty-transcripts exists to clear.
    static func transcriptAfterFailure(_ error: Error, cached: [TranscriptMoment]?) -> [TranscriptMoment]? {
        switch error {
        case YouTubeTranscriptKit.TranscriptError.noCaptionData,
             YouTubeTranscriptKit.TranscriptError.noTranscriptData:
            return cached ?? []
        default:
            return cached
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
