import Foundation
import OSLog

public struct FileDownloader {
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
        var fileName = url.lastPathComponent
        var localPath = (directory as NSString).appendingPathComponent(fileName)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: localPath) {
            return DownloadedAsset(originalUrl: url.absoluteString, localPath: fileName)
        }

        do {
            // Download the file
            let (downloadedURL, response) = try await URLSession.shared.download(from: url)

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
                if let name = response.suggestedFilename {
                    fileName = name
                    localPath = (directory as NSString).appendingPathComponent(fileName)
                }
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
