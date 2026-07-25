@testable import hunch
import ArgumentParser
import XCTest
import YouTubeTranscriptKit

final class ExportHelpersTests: XCTestCase {
    /// A limiter that has already given up, arrived at without touching the network.
    private func exhaustedLimiter() async -> YouTubeRateLimiter {
        let limiter = YouTubeRateLimiter(backoff: RateLimitBackoff(delays: [0.01]))
        _ = try? await limiter.withBackoff(onBan: .skipTheRest) { () -> String in
            throw YouTubeTranscriptKit.TranscriptError.rateLimited(statusCode: 200, url: nil)
        }
        return limiter
    }

    func testTranscriptFetchIsSkippedOnceTheLimiterHasGivenUp() async throws {
        let limiter = await exhaustedLimiter()
        XCTAssertTrue(limiter.hasGivenUp, "one ban is enough for the export policy")

        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("hunch-skipped-\(UUID().uuidString).json")

        let moments = await ExportHelpers.fetchAndCacheTranscript(for: "https://www.youtube.com/watch?v=abc",
                                                                  to: path,
                                                                  limiter: limiter)

        XCTAssertNil(moments)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path),
                       "a skipped fetch must cache nothing, so a later run can still fill the gap")
    }

    func testExportExitsNonZeroOnlyWhenTranscriptsWereSkipped() async throws {
        let healthy = YouTubeRateLimiter(backoff: RateLimitBackoff(delays: [0.01]))
        XCTAssertNil(ExportHelpers.exitCodeForSkippedTranscripts(limiter: healthy),
                     "a clean export should not be reported as a failure")

        let banned = await exhaustedLimiter()
        XCTAssertEqual(ExportHelpers.exitCodeForSkippedTranscripts(limiter: banned), ExitCode.failure,
                       "a scripted caller has to be able to tell a complete export from a gapped one")
    }
}
