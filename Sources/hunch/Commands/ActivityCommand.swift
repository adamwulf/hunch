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

        // Filter and group video activities by ID
        var videoActivities: [String: [(activity: Activity, title: String?)]] = [:]

        for activity in activities {
            if case .video(let id, let title) = activity.link {
                videoActivities[id, default: []].append((activity, title))
            }
        }

        // Sort each video's activities by date
        for (id, activities) in videoActivities {
            let sortedActivities = activities.sorted { $0.activity.timestamp < $1.activity.timestamp }
            videoActivities[id] = sortedActivities
        }

        // Process each video
        for (id, activities) in videoActivities {
            let videoPath = (normalizedOutputPath as NSString).appendingPathComponent(id)
            try fm.createDirectory(atPath: videoPath, withIntermediateDirectories: true)

            // Save activities as JSON array
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(activities.map { $0.activity })
            let jsonPath = (videoPath as NSString).appendingPathComponent("activities.json")
            try jsonData.write(to: URL(fileURLWithPath: jsonPath))

            // Set folder dates using first/last activity
            let firstSeen = activities.first!.activity.timestamp
            let lastSeen = activities.last!.activity.timestamp
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: firstSeen,
                .modificationDate: lastSeen
            ]
            try fm.setAttributes(attributes, ofItemAtPath: videoPath)
        }
    }
}
