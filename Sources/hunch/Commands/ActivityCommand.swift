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

        // Parse activity file
        let activities = try await YouTubeTranscriptKit.getActivity(fileURL: URL(fileURLWithPath: normalizedInputPath))

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
        let sortedVideos = videos.sorted { $0.lastSeen > $1.lastSeen }

        // Process each video
        for video in sortedVideos {
            let localizedName = video.title?.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "") ?? video.id
            let videoDir = (normalizedOutputPath as NSString).appendingPathComponent(video.id + ".localized")
            let localizedDir = (videoDir as NSString).appendingPathComponent(".localized")

            // Create directories
            try fm.createDirectory(atPath: videoDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: localizedDir, withIntermediateDirectories: true)

            // Create Base.strings file
            let escapedName = localizedName
                .replacingOccurrences(of: "\\", with: "\\\\")  // Must escape backslashes first
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let stringsContent = "\"\(video.id)\" = \"\(escapedName)\";"
            let stringsPath = (localizedDir as NSString).appendingPathComponent("Base.strings")
            try stringsContent.write(toFile: stringsPath, atomically: true, encoding: .utf8)

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

            if !fm.fileExists(atPath: infoPath) || !fm.fileExists(atPath: transcriptPath) {
                do {
                    let info = try await YouTubeTranscriptKit.getVideoInfo(videoID: video.id)

                    // Save transcript first if we have it
                    if let transcript = info.transcript {
                        let transcriptData = try encoder.encode(transcript)
                        try transcriptData.write(to: URL(fileURLWithPath: transcriptPath))
                    }

                    // Save info without transcript
                    let infoData = try encoder.encode(info.withoutTranscript())
                    try infoData.write(to: URL(fileURLWithPath: infoPath))
                } catch {
                    print("Failed to fetch info/transcript for \(video.id): \(error)")
                }
            }

            // Set folder dates using first/last activity
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: video.firstSeen,
                .modificationDate: video.lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoDir)
        }
    }
}
