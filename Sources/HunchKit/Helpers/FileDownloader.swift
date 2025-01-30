import Foundation
import OSLog
import UniformTypeIdentifiers
import CryptoKit

public struct FileDownloader {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    public struct DownloadedAsset {
        let originalUrl: String
        let localPath: String
    }

    private static let maxRetries = 3
    private static let minRetryDelay: TimeInterval = 1.0
    private static let maxRetryDelay: TimeInterval = 60.0

    public enum DownloadError: LocalizedError {
        case networkError(_ error: Error)
        case rateLimitExceeded(retryAfter: TimeInterval)

        var localizedDescription: String {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .rateLimitExceeded(let retryAfter):
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            }
        }
    }

    public static func downloadFile(from url: URL, to directory: String, retryCount: Int = 0) async throws -> DownloadedAsset {
        let urlString = url.absoluteString
        let sha = SHA256.hash(data: Data(urlString.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()

        var fileName = url.pathExtension.isEmpty ? sha : "\(sha).\(url.pathExtension)"
        var localPath = (directory as NSString).appendingPathComponent(fileName)

        // Check if file exists with any extension
        if let existingFile = try? FileManager.default.contentsOfDirectory(atPath: directory)
            .first(where: { $0.starts(with: sha) }) {
            return DownloadedAsset(originalUrl: url.absoluteString, localPath: existingFile)
        }

        do {
            // Download the file
            let (downloadedURL, response) = try await session.download(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                // Handle rate limit response
                if httpResponse.statusCode == 429 {
                    let retryAfter = TimeInterval(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "5") ?? 5

                    if retryCount < maxRetries {
                        let backoffDelay = min(
                            maxRetryDelay,
                            minRetryDelay * pow(2.0, Double(retryCount))
                        )
                        // Add one to ensure we're always after the requested delay instead of coming in milliseconds too soon
                        let delayInterval = 1 + max(retryAfter, backoffDelay)

                        NotionAPI.logHandler?(.error, "Download rate limit hit, retrying after \(delayInterval) seconds",
                            ["attempt": retryCount + 1, "max_attempts": maxRetries])

                        try? FileManager.default.removeItem(at: downloadedURL)
                        try await Task.sleep(nanoseconds: UInt64(delayInterval * 1_000_000_000))
                        return try await downloadFile(from: url, to: directory, retryCount: retryCount + 1)
                    } else {
                        NotionAPI.logHandler?(.fault, "Download rate limit retries exhausted", ["max_attempts": maxRetries])
                        throw DownloadError.rateLimitExceeded(retryAfter: retryAfter)
                    }
                }
                if let contentType = httpResponse.value(forHTTPHeaderField: "content-type"),
                   let utType = UTType(mimeType: contentType),
                   let ext = utType.preferredFilenameExtension {
                    fileName = "\(sha).\(ext)"
                } else if let suggestedExt = response.suggestedFilename?.components(separatedBy: ".").last {
                    fileName = "\(sha).\(suggestedExt)"
                }

                localPath = (directory as NSString).appendingPathComponent(fileName)
            }

            try FileManager.default.moveItem(at: downloadedURL, to: URL(fileURLWithPath: localPath))
            return DownloadedAsset(originalUrl: url.absoluteString, localPath: fileName)
        } catch {
            if let downloadError = error as? DownloadError {
                throw downloadError
            }
            throw DownloadError.networkError(error)
        }
    }
}
