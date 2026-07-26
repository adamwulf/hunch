import Foundation
import OSLog
import UniformTypeIdentifiers
import CryptoKit

public struct FileDownloader {
    /// Headers attached to every download.
    ///
    /// Assets are fetched from whichever host published them, which for a YouTube export means
    /// thumbnails from i.ytimg.com arriving moments after the watch page they were named in. A
    /// consumer presenting a browser identity to one host and the URLSession default to the other
    /// describes a client that does not exist, so the identity has to be settable here too rather
    /// than only on whichever session fetches the page.
    ///
    /// Setting this rebuilds the session, so it takes effect on the next download whenever it is
    /// called. Empty leaves URLSession's own defaults alone, which is what happens if nobody sets it.
    public static var additionalHeaders: [String: String] {
        get { return state.headers }
        set { state.headers = newValue }
    }

    private static var session: URLSession {
        return state.session
    }

    private static let state = State()

    /// Guards the session against a reader racing a caller that is replacing the headers.
    ///
    /// In practice a consumer sets the headers once at startup and never again, but a shared mutable
    /// static is not the place to rely on that holding forever.
    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var storedHeaders: [String: String] = [:]
        private var storedSession: URLSession

        init() {
            storedSession = State.makeSession(headers: [:])
        }

        var headers: [String: String] {
            get {
                lock.lock()
                defer { lock.unlock() }
                return storedHeaders
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                storedHeaders = newValue
                storedSession = State.makeSession(headers: newValue)
            }
        }

        var session: URLSession {
            lock.lock()
            defer { lock.unlock() }
            return storedSession
        }

        private static func makeSession(headers: [String: String]) -> URLSession {
            let config = URLSessionConfiguration.ephemeral
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.httpCookieStorage = nil
            config.urlCache = nil
            if !headers.isEmpty {
                config.httpAdditionalHeaders = headers
            }
            return URLSession(configuration: config)
        }
    }

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

    public static func downloadFile(from url: URL, to directory: String, retryCount: Int = 0) async throws -> DownloadedAsset {
        let sha = shaName(for: url)

        var fileName = url.pathExtension.isEmpty ? sha : "\(sha).\(url.pathExtension)"
        var localPath = (directory as NSString).appendingPathComponent(fileName)

        if let cached = cachedAsset(from: url, in: directory) {
            return cached
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
                } else if httpResponse.statusCode < 200 || httpResponse.statusCode > 299 {
                    let data = try? await session.data(from: url).0
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
