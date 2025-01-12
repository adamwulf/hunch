import Foundation
import ArgumentParser
import YouTubeTranscriptKit

struct ActivityCommand: AsyncParsableCommand {
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

        // Track earliest/latest dates per video
        var videoFirstSeen: [String: Date] = [:]
        var videoLastSeen: [String: Date] = [:]

        // First pass: collect dates
        for activity in activities {
            if case .video(let id, _) = activity.link {
                if let firstSeen = videoFirstSeen[id] {
                    videoFirstSeen[id] = min(firstSeen, activity.timestamp)
                } else {
                    videoFirstSeen[id] = activity.timestamp
                }

                if let lastSeen = videoLastSeen[id] {
                    videoLastSeen[id] = max(lastSeen, activity.timestamp)
                } else {
                    videoLastSeen[id] = activity.timestamp
                }
            }
        }

        // Second pass: save activities
        for activity in activities {
            if case .video(let id, _) = activity.link {
                let videoPath = (normalizedOutputPath as NSString).appendingPathComponent(id)
                try fm.createDirectory(atPath: videoPath, withIntermediateDirectories: true)

                // Save activity as JSON
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted]
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(activity)
                let jsonPath = (videoPath as NSString).appendingPathComponent("activity.json")
                try jsonData.write(to: URL(fileURLWithPath: jsonPath))

                // Set folder dates
                if let firstSeen = videoFirstSeen[id], let lastSeen = videoLastSeen[id] {
                    let attributes: [FileAttributeKey: Any] = [
                        .creationDate: firstSeen,
                        .modificationDate: lastSeen
                    ]
                    try fm.setAttributes(attributes, ofItemAtPath: videoPath)
                }
            }
        }
    }
}
