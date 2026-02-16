import Foundation
import ArgumentParser
import HunchKit
import YouTubeTranscriptKit

struct ExportCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export database pages to markdown files"
    )

    @Argument(help: "The Notion database ID to export")
    var databaseId: String

    @Option(name: .shortAndLong, help: "Output directory path")
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
            let localizedName = page.title.map({ $0.plainText })
                .joined()
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "")
            let pageDir = (normalizedPath as NSString).appendingPathComponent(page.id + ".localized")
            let localizedDir = (pageDir as NSString).appendingPathComponent(".localized")
            let assetsDir = (pageDir as NSString).appendingPathComponent("assets")
            var didCreateAssetsDir = false

            // Create directories
            try fm.createDirectory(atPath: pageDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: localizedDir, withIntermediateDirectories: true)

            // Create Base.strings file
            let escapedName = localizedName
                .replacingOccurrences(of: "\\", with: "\\\\")  // Must escape backslashes first
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let stringsContent = "\"\(page.id)\" = \"\(escapedName)\";"
            let stringsPath = (localizedDir as NSString).appendingPathComponent("Base.strings")
            try stringsContent.write(toFile: stringsPath, atomically: true, encoding: .utf8)

            // Cache page properties
            let propertiesJsonPath = (pageDir as NSString).appendingPathComponent("properties.json")
            let propertiesEncoder = JSONEncoder()
            propertiesEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let propertiesData = try propertiesEncoder.encode(page.properties)
            try propertiesData.write(to: URL(fileURLWithPath: propertiesJsonPath))

            // After creating pageDir
            let contentJsonPath = (pageDir as NSString).appendingPathComponent("content.json")

            // Load or fetch blocks
            let blocks: [Block]
            if fm.fileExists(atPath: contentJsonPath),
               let jsonData = try? Data(contentsOf: URL(fileURLWithPath: contentJsonPath)),
               let cachedBlocks = try? JSONDecoder().decode([Block].self, from: jsonData) {
                blocks = cachedBlocks
            } else {
                blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)
                // Cache the blocks
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(blocks)
                try jsonData.write(to: URL(fileURLWithPath: contentJsonPath))
            }

            // Load or fetch transcript if YouTube URL exists
            let transcript: [TranscriptMoment]?
            let youtubeUrl = findYouTubeUrl(in: page.properties)
            if let youtubeUrl = youtubeUrl {
                let transcriptJsonPath = (pageDir as NSString).appendingPathComponent("transcript.json")
                if fm.fileExists(atPath: transcriptJsonPath),
                   let jsonData = try? Data(contentsOf: URL(fileURLWithPath: transcriptJsonPath)),
                   let cachedMoments = try? JSONDecoder().decode([TranscriptMoment].self, from: jsonData) {
                    transcript = cachedMoments
                } else {
                    transcript = await fetchAndCacheTranscript(for: youtubeUrl, to: transcriptJsonPath)
                }
            } else {
                transcript = nil
            }

            // Download assets and collect their local paths
            var downloadedAssets: [String: FileDownloader.DownloadedAsset] = [:]

            func checkAssetsIn(blocks: [Block]) async throws {
                for block in blocks {
                    let assetUrl: String? = {
                        switch block.blockTypeObject {
                        case .image(let image):
                            return image.image.type.url
                        case .video(let video):
                            return video.type.url
                        case .audio(let audio):
                            return audio.type.url
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
                            print("Failed to download asset for page \(page.id):\n\(url)")
                        }
                    }

                    if !block.children.isEmpty {
                        try await checkAssetsIn(blocks: block.children)
                    }
                }
            }

            try await checkAssetsIn(blocks: blocks)

            // Create renderer with downloaded assets
            let renderer = MarkdownRenderer(
                level: 0,
                ignoreColor: false,
                ignoreUnderline: false,
                downloadedAssets: downloadedAssets)

            // Render to markdown
            let emoji = page.icon?.emoji.map({ $0 + " " }) ?? ""
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = .utc
            dateFormatter.formatOptions = [.withInternetDateTime]

            // Extract select properties
            let selectProperties = page.properties
                .sorted(by: { $0.key < $1.key })
                .compactMap { (name: String, prop: Property) -> (String, [String])? in
                    switch prop {
                    case .multiSelect(_, let values):
                        return (name, values.map { $0.name })
                    case .select(_, let values):
                        return (name, values.map { $0.name })
                    case .url(_, let value):
                        return (name, [value])
                    case .formula(_, let value):
                        return (name, [value.type.stringValue ?? ""])
                    case .checkbox(_, let value):
                        return (name, [value ? "Yes" : "No"])
                    case .number(_, let value):
                        return (name, [String(value)])
                    case .date(_, let value):
                        let formatter = ISO8601DateFormatter()
                        let start = formatter.string(from: value.start)
                        let end = value.end.map { formatter.string(from: $0) }
                        return (name, [start] + (end.map { [" - ", $0] } ?? []))
                    case .email(_, let value):
                        return (name, [value])
                    case .phoneNumber(_, let value):
                        return (name, [value])
                    case .relation(_, let values):
                        return (name, values.map { $0.id })
                    case .rollup(_, let value):
                        return (name, [value.value])
                    case .people(_, let users):
                        return (name, users.compactMap { $0.name })
                    case .file(_, let files), .files(_, let files):
                        return (name, files.map { $0.url })
                    case .createdBy(_, let user):
                        return (name, [user.name].compactMap({ $0 }))
                    case .lastEditedBy(_, let user):
                        return (name, [user.name].compactMap({ $0 }))
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
            var markdown = titleHeader + (try renderer.render([page] + blocks))

            // Add transcript if we have moments
            if let youtubeUrl = youtubeUrl, let transcript = transcript {
                markdown += "\n\n## Transcript\n\n"
                for moment in transcript {
                    let seconds = Int(moment.start)
                    let timestamp = String(format: "[%d:%02d]", seconds / 60, seconds % 60)
                    let timestampURL = addTimestamp(to: youtubeUrl, seconds: seconds)
                    let transcriptText = moment.text.replacingOccurrences(of: "\n", with: " ")
                    markdown += "[\(timestamp)](\(timestampURL)) \(transcriptText)\n"
                }
            }

            // Write to file
            let filePath = (pageDir as NSString).appendingPathComponent("content.md")
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)

            // Add this helper function
            try writeWebloc(pageId: page.id, title: page.title, to: pageDir)

            // Set folder dates AFTER all async downloads and file operations
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: page.created,
                .modificationDate: page.lastEdited
            ]
            try fm.setAttributes(attributes, ofItemAtPath: pageDir)
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

        // Ensure filename + .webloc is <= 255 chars
        let ext = ".webloc"
        let maxLength = 255 - ".webloc".count
        if filename.count > maxLength {
            filename = String(filename.prefix(maxLength))
        }

        let filePath = (directory as NSString).appendingPathComponent("\(filename.filenameSafe + ext)")
        try weblocContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    // Update helper to return the YouTube URL if found
    private func findYouTubeUrl(in properties: [String: Property]) -> String? {
        for (_, prop) in properties {
            if case .url(_, let value) = prop {
                if value.contains("youtube.com") {
                    return value
                }
            }
        }
        return nil
    }

    private func addTimestamp(to youtubeUrl: String, seconds: Int) -> String {
        // Remove any existing t parameter
        var urlComps = URLComponents(string: youtubeUrl)!
        urlComps.queryItems = urlComps.queryItems?.filter { $0.name != "t" }
        if urlComps.queryItems == nil {
            urlComps.queryItems = []
        }
        urlComps.queryItems!.append(URLQueryItem(name: "t", value: String(seconds)))
        return urlComps.url!.absoluteString
    }

    private func fetchAndCacheTranscript(for url: String, to path: String) async -> [TranscriptMoment]? {
        do {
            let transcript = try await YouTubeTranscriptKit.getTranscript(url: URL(string: url)!)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(transcript)
            try jsonData.write(to: URL(fileURLWithPath: path))
            return transcript
        } catch {
            print("Failed to fetch transcript for \(url): \(error)")
            return nil
        }
    }
}
