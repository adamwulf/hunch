import Foundation
import ArgumentParser
import YouTubeTranscriptKit

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

        // Process each video with rate limiting
        for (index, video) in sortedVideos.enumerated() {
            print("[\(index + 1)/\(sortedVideos.count)] Processing \(video.id)")

            // Build all URLs
            let videoURL = outputURL.appendingPathComponent(video.id + ".localized")
            let localizedURL = videoURL.appendingPathComponent(".localized")
            let activitiesURL = videoURL.appendingPathComponent("activities.json")
            let infoURL = videoURL.appendingPathComponent("info.json")
            let transcriptURL = videoURL.appendingPathComponent("transcript.json")
            let stringsURL = localizedURL.appendingPathComponent("Base.strings")

            // Create all directories first
            try fm.createDirectory(at: videoURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: localizedURL, withIntermediateDirectories: true)

            // Verify directories were created
            var isDirectory: ObjCBool = false
            guard
                fm.fileExists(atPath: videoURL.path, isDirectory: &isDirectory), isDirectory.boolValue,
                fm.fileExists(atPath: localizedURL.path, isDirectory: &isDirectory), isDirectory.boolValue
            else {
                throw NSError(domain: "ActivityCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create directories for video \(video.id)"])
            }

            // Load cached data
            let info: VideoInfo? = {
                guard let data = try? Data(contentsOf: infoURL) else { return nil }
                return try? decoder.decode(VideoInfo.self, from: data)
            }()

            let transcript: [TranscriptMoment]? = {
                guard let data = try? Data(contentsOf: transcriptURL) else { return nil }
                return try? decoder.decode([TranscriptMoment].self, from: data)
            }()

            // Process data with exponential backoff on failure
            let finalInfo: VideoInfo?
            let finalTranscript: [TranscriptMoment]?
            do {
                switch (info, transcript) {
                case (nil, nil):
                    print("  Fetching info and transcript")
                    let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: true)
                    finalInfo = fetched.withoutTranscript()
                    finalTranscript = fetched.transcript
                case (nil, .some(let cached)):
                    print("  Fetching info")
                    let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: false)
                    finalInfo = fetched.withoutTranscript()
                    finalTranscript = cached
                case (.some(let cached), nil):
                    print("  Fetching transcript")
                    let moments = try await YouTubeTranscriptKit.getTranscript(videoID: video.id)
                    finalInfo = cached
                    finalTranscript = moments
                case (.some(let cached), .some(let cachedTranscript)):
                    print("  Using cached data")
                    finalInfo = cached
                    finalTranscript = cachedTranscript
                }
            } catch {
                print("  Error: \(error)")

                // Only sleep on network errors
                if case YouTubeTranscriptKit.TranscriptError.networkError = error {
                    print("  Network error - backing off for 5s")
                    try await Task.sleep(for: .seconds(5))
                }

                finalInfo = nil
                finalTranscript = nil
            }

            let videoTitle = finalInfo?.title ?? video.title
            let localizedName = videoTitle?.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "") ?? video.id
            let escapedName = localizedName
                .replacingOccurrences(of: "\\", with: "\\\\")  // Must escape backslashes first
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let stringsContent = "\"\(video.id)\" = \"\(escapedName)\";"

            // Write all data to disk
            try encoder.encode(video.activities).write(to: activitiesURL)
            if let finalInfo = finalInfo {
                try encoder.encode(finalInfo).write(to: infoURL)
            }
            if let finalTranscript = finalTranscript {
                try encoder.encode(finalTranscript).write(to: transcriptURL)
            }
            try stringsContent.write(to: stringsURL, atomically: true, encoding: .utf8)

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
}
