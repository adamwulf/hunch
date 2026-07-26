import Foundation
import ArgumentParser
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

    /// Fetches a transcript and caches it beside the exported page, returning nil when there is
    /// nothing to cache.
    ///
    /// An export is mostly a Notion job, so a YouTube ban skips transcripts for the rest of the run
    /// instead of stalling the export for hours the way `hunch activity` deliberately does. The
    /// export commands report the shortfall and exit non zero, and nothing is cached on failure, so
    /// a later run fills the gaps in.
    static func fetchAndCacheTranscript(for url: String, to path: String,
                                        limiter: YouTubeRateLimiter = .shared) async -> [TranscriptMoment]? {
        // The limiter already refuses to touch the network once it has given up. This check exists
        // only so the explanation is printed once rather than once per remaining page.
        guard !limiter.hasGivenUp else { return nil }

        do {
            let transcript = try await limiter.withBackoff(onBan: .skipTheRest) {
                try await YouTubeTranscriptKit.getTranscript(url: URL(string: url)!)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(transcript)
            try jsonData.write(to: URL(fileURLWithPath: path))
            return transcript
        } catch let banned as YouTubeRateLimiter.RateLimitExhausted {
            // Printed exactly once, since every later page short circuits on the guard above
            print(banned.localizedDescription)
            return nil
        } catch {
            print("Failed to fetch transcript for \(url): \(error)")
            return nil
        }
    }

    /// Ends an export non zero when YouTube banned us partway through, so a scripted caller can
    /// tell a complete export from one quietly missing every transcript after page twelve.
    static func exitCodeForSkippedTranscripts(limiter: YouTubeRateLimiter = .shared) -> ExitCode? {
        guard limiter.hasGivenUp else { return nil }
        print("Some pages were exported without transcripts because YouTube rate limited this IP. "
              + "Re-run this export once the rate limit clears to fill them in.")
        return .failure
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
