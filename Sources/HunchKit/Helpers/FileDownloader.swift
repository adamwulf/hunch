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
        case httpError(code: Int, url: String, headers: [AnyHashable: Any], body: String?)

        var localizedDescription: String {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .rateLimitExceeded(let retryAfter):
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            case .httpError(let code, let url, let headers, let body):
                return """
                    HTTP \(code): \(url)
                    Headers: \(headers)
                    Body: \(body ?? "<no body>")
                    """
            }
        }
    }

    /// Every rate limited response this process has seen while downloading, including the ones the
    /// retry loop below absorbed without telling anybody.
    ///
    /// A caller pacing its own traffic cannot learn this any other way. `downloadFile` retries a 429
    /// up to `maxRetries` times and only throws once it runs out, so a throttle that clears on the
    /// second attempt is invisible from outside, and a download that fails outright reports a single
    /// error for what may have been four rate limited responses. Those absorbed responses are the
    /// earliest evidence that a run is going too fast, which is what makes them worth counting.
    public static var rateLimitCount: Int {
        return counter.value
    }

    private static let counter = Counter()

    /// A counter shared across every download in the process, which is exactly the scope a caller
    /// needs: hosts rate limit by client, not by file.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }

        func increment() {
            lock.lock()
            defer { lock.unlock() }
            stored += 1
        }
    }

    /// The already downloaded copy of `url`, or nil when fetching it would reach the network.
    ///
    /// `downloadFile` consults this first, so calling it changes nothing on its own. It is public so
    /// a caller that paces its network traffic can tell the two cases apart before committing to a
    /// wait: an asset already on disk costs nothing and must not cost a delay either.
    public static func cachedAsset(from url: URL, in directory: String) -> DownloadedAsset? {
        let sha = shaName(for: url)

        // Check if file exists with any extension
        guard let existingFile = try? FileManager.default.contentsOfDirectory(atPath: directory)
            .first(where: { $0.starts(with: sha) }) else { return nil }

        return DownloadedAsset(originalUrl: url.absoluteString, localPath: existingFile)
    }

    private static func shaName(for url: URL) -> String {
        return SHA256.hash(data: Data(url.absoluteString.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// Downloads `url` into `directory`, returning the copy already there when there is one.
    ///
    /// `headers` are sent with this request only. Deliberately per call rather than per session: the
    /// identity that is right for one host is wrong for another, and a download helper shared by
    /// every part of the app is the last place to keep an opinion about who the caller is pretending
    /// to be. A caller presenting a browser to a media host should not thereby present one to an
    /// unrelated API.
    public static func downloadFile(from url: URL, to directory: String, retryCount: Int = 0,
                                    headers: [String: String] = [:]) async throws -> DownloadedAsset {
        let sha = shaName(for: url)

        var fileName = url.pathExtension.isEmpty ? sha : "\(sha).\(url.pathExtension)"
        var localPath = (directory as NSString).appendingPathComponent(fileName)

        if let cached = cachedAsset(from: url, in: directory) {
            return cached
        }

        var request = URLRequest(url: url)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            // Download the file
            let (downloadedURL, response) = try await session.download(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                // Handle rate limit response
                if httpResponse.statusCode == 429 {
                    // Counted before the retry decision, so the responses this loop absorbs are on
                    // the record rather than only the ones that outlive it
                    counter.increment()

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
                        return try await downloadFile(from: url, to: directory, retryCount: retryCount + 1,
                                                      headers: headers)
                    } else {
                        NotionAPI.logHandler?(.fault, "Download rate limit retries exhausted", ["max_attempts": maxRetries])
                        throw DownloadError.rateLimitExceeded(retryAfter: retryAfter)
                    }
                } else if httpResponse.statusCode < 200 || httpResponse.statusCode > 299 {
                    let data = try? await session.data(for: request).0
                    let body = data.flatMap { String(data: $0, encoding: .utf8) }
                    throw DownloadError.httpError(
                        code: httpResponse.statusCode,
                        url: url.absoluteString,
                        headers: httpResponse.allHeaderFields,
                        body: body
                    )
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
