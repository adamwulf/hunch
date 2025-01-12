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

        print("Found \(activities.count) activities")
    }
}
