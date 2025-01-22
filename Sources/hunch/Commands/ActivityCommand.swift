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

    static var configuration = CommandConfiguration(
        commandName: "activity",
        abstract: "Parse Google Takeout MyActivity.html file"
    )

    @Argument(help: "Path to MyActivity.html file")
    var activityPath: String

    @Option(name: .shortAndLong, help: "Output directory path")
    var outputDir: String = "./activity_export"

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

        let confident = 29600 // -> 27100
        let skip = confident + 0

        // Process each video with rate limiting
        for (index, video) in sortedVideos[skip...].enumerated() {
            if index > 0, index % 17 == 0 {
                print("Resting for 2 seconds...")
                try await Task.sleep(for: .seconds(2))
            } else if index > 0, index % 50 == 0 {
                print("Resting for 5 seconds...")
                try await Task.sleep(for: .seconds(5))
            } else if index > 0, index % (37 * 7) == 0 {
                print("Resting for 37 seconds...")
                try await Task.sleep(for: .seconds(17))
            }
            // Only print progress every 100 items
            if index % 100 == 0 {
                let trueIndex = index + skip
                let progress = Double(trueIndex) / Double(sortedVideos.count) * 100
                let dateStr = progressDateFormatter.string(from: video.lastSeen)
                let indexStr = "[\(trueIndex)/\(sortedVideos.count)]".padding(toLength: 15, withPad: " ", startingAt: 0)
                let dateColumn = dateStr.padding(toLength: 10, withPad: " ", startingAt: 0)
                let percentStr = String(format: "%6.1f%%", progress)
                print("\(indexStr) \(dateColumn) \(percentStr)")
            }

            // Build all URLs
            let videoURL = outputURL.appendingPathComponent(video.id + ".localized")
            let localizedURL = videoURL.appendingPathComponent(".localized")
            let activitiesURL = videoURL.appendingPathComponent("activities.json")
            let infoURL = videoURL.appendingPathComponent("info.json")
            let transcriptURL = videoURL.appendingPathComponent("transcript.json")
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

            let transcript: [TranscriptMoment]? = {
                guard
                    let data = try? Data(contentsOf: transcriptURL),
                    let loaded = try? decoder.decode([TranscriptMoment].self, from: data)
                else { return nil}
                return loaded.isEmpty ? nil : loaded
            }()

            // Process data with exponential backoff on failure
            let finalInfo: VideoInfo?
            let finalTranscript: [TranscriptMoment]?
            do {
                switch (info, transcript) {
                case (nil, nil):
                    try await Task.sleep(for: .milliseconds(300))
                    let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: true)
                    finalInfo = fetched.withoutTranscript()
                    finalTranscript = fetched.transcript
                    print("Fetched \(video.id)\(fetched.transcript == nil ? "" : " with transcript")")
                case (nil, .some(let cached)):
                    try await Task.sleep(for: .seconds(1))
                    print("Fetching info: \(video.id)")
                    let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: false)
                    finalInfo = fetched.withoutTranscript()
                    finalTranscript = cached
                case (.some(let cached), nil):
                    try await Task.sleep(for: .seconds(1))
                    // Skip fetching transcript if we already have info
                    print("Fetching transcript: \(video.id)")
                    let moments = try await YouTubeTranscriptKit.getTranscript(videoID: video.id)
                    finalInfo = cached
                    finalTranscript = moments.isEmpty ? nil : moments
                    if !moments.isEmpty {
                        print("  recovered")
                    }
                case (.some(let cached), .some(let cachedTranscript)):
                    finalInfo = cached
                    finalTranscript = cachedTranscript
                }
            } catch {
                if case YouTubeTranscriptKit.TranscriptError.noCaptionData = error {
                    // noop
                } else {
                    print("Error processing \(video.id): \(error)")
                }

                // Only sleep on network errors
                if case YouTubeTranscriptKit.TranscriptError.networkError(let nwError) = error {
                    print("  backing off for 5s: \(nwError)")
                    try await Task.sleep(for: .seconds(5))
                }

                finalInfo = info
                finalTranscript = transcript
            }

            // Now download thumbnails after we have finalInfo
            if let thumbnails = finalInfo?.thumbnails {
                // Create assets directory only if we have thumbnails
                try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)

                for thumbnail in thumbnails {
                    if let url = URL(string: thumbnail.url) {
                        do {
                            let asset = try await FileDownloader.downloadFile(from: url, to: assetsDir.path(percentEncoded: false))
                            downloadedAssets[thumbnail.url] = asset
                        } catch {
                            print("Failed to download thumbnail: \(url)")
                        }
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

            try writeMarkdown(video: video, info: finalInfo, transcript: finalTranscript,
                              downloadedAssets: downloadedAssets, to: videoURL.path)

            // Set folder dates
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: video.firstSeen,
                .modificationDate: video.lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoURL.path)
        }
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

    private func writeMarkdown(video: VideoData, info: VideoInfo?, transcript: [TranscriptMoment]?,
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
            ---

            """

        // Create renderer with our downloaded assets
        let renderer = MarkdownRenderer(level: 0, ignoreColor: false, ignoreUnderline: false, downloadedAssets: downloadedAssets)

        // Add largest thumbnail if available
        if let thumbnails = info?.thumbnails?.sorted(by: { $0.width * $0.height > $1.width * $1.height }), let thumb = thumbnails.first {
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

        if let transcript = transcript {
            markdown += "\n## Transcript\n\n"
            let hasHours = (info?.duration ?? 0) > 3600
            var lastTimeBlock = -1
            for moment in transcript {
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
