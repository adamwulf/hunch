import Foundation

public struct FileDownloader {
    public struct DownloadedAsset {
        let originalUrl: String
        let localPath: String
    }

    public static func downloadFile(from url: URL, to directory: String) async throws -> DownloadedAsset {
        let fileName = url.lastPathComponent
        let localPath = (directory as NSString).appendingPathComponent(fileName)

        // Check if file already exists
        if FileManager.default.fileExists(atPath: localPath) {
            return DownloadedAsset(originalUrl: url.absoluteString, localPath: fileName)
        }

        // Download the file
        let (downloadedURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: downloadedURL, to: URL(fileURLWithPath: localPath))

        return DownloadedAsset(originalUrl: url.absoluteString, localPath: fileName)
    }
}
