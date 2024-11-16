import Foundation
import ArgumentParser
import HunchKit

struct ExportCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export database pages to markdown files"
    )

    @Argument(help: "The Notion database ID to export")
    var databaseId: String

    @Option(name: .long, help: "Output directory path")
    var outputDir: String = "./notion_export"

    mutating func run() async throws {
        let fm = FileManager.default

        // Normalize output path
        let normalizedPath = ((outputDir as NSString)
            .expandingTildeInPath as NSString)
            .standardizingPath

        // Fetch database pages
        let pages = try await HunchAPI.shared.fetchPages(databaseId: databaseId)

        // Create output directory if it doesn't exist
        try fm.createDirectory(atPath: normalizedPath, withIntermediateDirectories: true)

        // Process each page
        for page in pages {
            let pageDir = (normalizedPath as NSString).appendingPathComponent(page.id)

            // Create directory for this page
            try fm.createDirectory(atPath: pageDir, withIntermediateDirectories: true)

            // Fetch page blocks
            let blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)

            // Render to markdown
            let emoji = page.icon?.emoji.map({ $0 + " " }) ?? ""
            let renderer = MarkdownRenderer(level: 0, ignoreColor: false, ignoreUnderline: false)
            let titleHeader = "# \(emoji)" + (try renderer.render(page.title)) + "\n\n"
            let markdown = titleHeader + (try renderer.render([page] + blocks))

            // Write to file
            let filePath = (pageDir as NSString).appendingPathComponent("content.md")
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }
}
