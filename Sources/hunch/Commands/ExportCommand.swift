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
            let assetsDir = (pageDir as NSString).appendingPathComponent("assets")
            var didCreateAssetsDir = false

            // Create directory for this page
            try fm.createDirectory(atPath: pageDir, withIntermediateDirectories: true)

            // Fetch page blocks
            let blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)

            // Download assets and collect their local paths
            var downloadedAssets: [String: FileDownloader.DownloadedAsset] = [:]
            for block in blocks {
                let assetUrl: String? = {
                    switch block.blockTypeObject {
                    case .image(let image):
                        return image.image.type.url
                    case .video(let video):
                        return video.type.url
                    case .file(let file):
                        return file.type.url
                    case .pdf(let pdf):
                        return pdf.pdf.type.url
                    default:
                        return nil
                    }
                }()

                if let urlString = assetUrl, let url = URL(string: urlString) {
                    if !didCreateAssetsDir {
                        // only create the assets directory if we actuallly need it
                        didCreateAssetsDir = true
                        try fm.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)
                    }
                    do {
                        let asset = try await FileDownloader.downloadFile(from: url, to: assetsDir)
                        downloadedAssets[urlString] = asset
                    } catch {
                        print("Failed to download asset: \(url)")
                    }
                }
            }

            // Create renderer with downloaded assets
            let renderer = MarkdownRenderer(level: 0,
                                          ignoreColor: false,
                                          ignoreUnderline: false,
                                          downloadedAssets: downloadedAssets)

            // Render to markdown
            let emoji = page.icon?.emoji.map({ $0 + " " }) ?? ""
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = .utc
            dateFormatter.formatOptions = [.withInternetDateTime]

            // Extract select properties
            let selectProperties = page.properties.compactMap { (name: String, prop: Property) -> (String, [String])? in
                switch prop {
                case .multiSelect(_, let values):
                    return (name, values.map { $0.name })
                case .select(_, let value):
                    return (name, [value.name])
                case .url(_, let value):
                    return (name, [value])
                default:
                    return nil
                }
            }

            let titleHeader = """
                ---
                title: "\(emoji)\(try renderer.render(page.title))"
                created: \(dateFormatter.string(from: page.created))
                lastEdited: \(dateFormatter.string(from: page.lastEdited))
                archived: \(page.archived)
                id: \(page.id)
                \(selectProperties.map { name, values in
                    "\(name.lowercased()): \(values.joined(separator: ", "))"
                }.joined(separator: "\n"))
                ---


                """ // format to ensure an newline between the metadata and page content
            let markdown = titleHeader + (try renderer.render([page] + blocks))

            // Write to file
            let filePath = (pageDir as NSString).appendingPathComponent("content.md")
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)

            // Add this helper function
            try writeWebloc(pageId: page.id, title: page.title, to: pageDir)
        }
    }

    // Add this helper function
    private func writeWebloc(pageId: String, title: [RichText], to directory: String) throws {
        let weblocContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>URL</key>
            <string>https://www.notion.so/\(pageId.replacingOccurrences(of: "-", with: ""))</string>
        </dict>
        </plist>
        """

        var filename = title.map({ $0.plainText }).joined()
        if filename.isEmpty {
            filename = "Link"
        }
        let filePath = (directory as NSString).appendingPathComponent("\(filename).webloc")
        try weblocContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
