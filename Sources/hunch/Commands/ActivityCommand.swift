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

        // Normalize input path
        let normalizedInputPath = ((activityPath as NSString)
            .expandingTildeInPath as NSString)
            .standardizingPath

        // Normalize output path
        let normalizedOutputPath = ((outputDir as NSString)
            .expandingTildeInPath as NSString)
            .standardizingPath

        // Create output directory if it doesn't exist
        try fm.createDirectory(atPath: normalizedOutputPath, withIntermediateDirectories: true)

        // Parse activities and get sorted videos
        let sortedVideos = try await parseActivities(from: normalizedInputPath)

        // Process each video
        for video in sortedVideos[...10] {
            let videoDir = (normalizedOutputPath as NSString).appendingPathComponent(video.id + ".localized")
            let localizedDir = (videoDir as NSString).appendingPathComponent(".localized")

            // Create directories
            try fm.createDirectory(atPath: videoDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: localizedDir, withIntermediateDirectories: true)

            // Save activities as JSON array
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let activitiesData = try encoder.encode(video.activities)
            let activitiesPath = (videoDir as NSString).appendingPathComponent("activities.json")
            try activitiesData.write(to: URL(fileURLWithPath: activitiesPath))

            // Load or fetch video info and transcript
            let infoPath = (videoDir as NSString).appendingPathComponent("info.json")
            let transcriptPath = (videoDir as NSString).appendingPathComponent("transcript.json")

            // Try loading from cache first
            let info: VideoInfo? = {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: infoPath)) else { return nil }
                return try? JSONDecoder().decode(VideoInfo.self, from: data)
            }()

            let transcript: [TranscriptMoment]? = {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: transcriptPath)) else { return nil }
                return try? JSONDecoder().decode([TranscriptMoment].self, from: data)
            }()

            // Fetch what we're missing based on cache state
            let finalInfo: VideoInfo
            let finalTranscript: [TranscriptMoment]?
            switch (info, transcript) {
            case (nil, nil):
                let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: true)
                try encoder.encode(fetched.withoutTranscript()).write(to: URL(fileURLWithPath: infoPath))
                if let fetchedTranscript = fetched.transcript {
                    try encoder.encode(fetchedTranscript).write(to: URL(fileURLWithPath: transcriptPath))
                }
                finalInfo = fetched.withoutTranscript()
                finalTranscript = fetched.transcript
            case (nil, .some(let cached)):
                let fetched = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id, includeTranscript: false)
                try encoder.encode(fetched.withoutTranscript()).write(to: URL(fileURLWithPath: infoPath))
                finalInfo = fetched.withoutTranscript()
                finalTranscript = cached
            case (.some(let cached), nil):
                let moments = try await YouTubeTranscriptKit.getTranscript(videoID: video.id)
                try encoder.encode(moments).write(to: URL(fileURLWithPath: transcriptPath))
                finalInfo = cached
                finalTranscript = moments
            case (.some(let cached), .some(let cachedTranscript)):
                finalInfo = cached
                finalTranscript = cachedTranscript
            }

            // Calculate best available title
            let videoTitle = finalInfo.title ?? video.title

            // Create Base.strings file with best available title
            let localizedName = videoTitle?.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "") ?? video.id
            let escapedName = localizedName
                .replacingOccurrences(of: "\\", with: "\\\\")  // Must escape backslashes first
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let stringsContent = "\"\(video.id)\" = \"\(escapedName)\";"
            let stringsPath = (localizedDir as NSString).appendingPathComponent("Base.strings")
            try stringsContent.write(toFile: stringsPath, atomically: true, encoding: .utf8)

            // Set folder dates using first/last activity
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: video.firstSeen,
                .modificationDate: video.lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoDir)
        }
    }

    private func parseActivities(from path: String) async throws -> [VideoData] {
        // Parse activity file
        let activities = try await YouTubeTranscriptKit.getActivity(fileURL: URL(fileURLWithPath: path))

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
