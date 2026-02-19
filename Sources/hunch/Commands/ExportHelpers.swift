import Foundation
import HunchKit
import YouTubeTranscriptKit

enum ExportHelpers {

    static func writeWebloc(pageId: String, title: [RichText], to directory: String) throws {
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

    static func findYouTubeUrl(in properties: [String: Property]) -> String? {
        for (_, prop) in properties {
            if case .url(_, let value) = prop {
                if value.contains("youtube.com") {
                    return value
                }
            }
        }
        return nil
    }

    static func addTimestamp(to youtubeUrl: String, seconds: Int) -> String {
        // Remove any existing t parameter
        var urlComps = URLComponents(string: youtubeUrl)!
        urlComps.queryItems = urlComps.queryItems?.filter { $0.name != "t" }
        if urlComps.queryItems == nil {
            urlComps.queryItems = []
        }
        urlComps.queryItems!.append(URLQueryItem(name: "t", value: String(seconds)))
        return urlComps.url!.absoluteString
    }

    static func fetchAndCacheTranscript(for url: String, to path: String) async -> [TranscriptMoment]? {
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

    static func selectProperties(from properties: [String: Property]) -> [(String, [String])] {
        return properties
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
    }
}
