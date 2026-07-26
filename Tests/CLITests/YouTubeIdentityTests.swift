@testable import hunch
import XCTest
import YouTubeTranscriptKit

final class YouTubeIdentityTests: XCTestCase {
    override func tearDown() {
        // The kit's configuration is process wide, so hand it back the way it was found
        YouTubeTranscriptKit.configure(.init())
        super.tearDown()
    }

    func testInstallingTheIdentityReachesTheKit() {
        YouTubeIdentity.install()

        let headers = YouTubeTranscriptKit.configuration.additionalHeaders
        XCTAssertEqual(headers["User-Agent"], YouTubeIdentity.userAgent)
        XCTAssertEqual(headers["Accept-Language"], "en-US,en;q=0.9")
    }

    /// Each of these tokens looks like a mistake and is not. They were read out of a real browser,
    /// and every one of them has already been queried once by someone reading this string, so the
    /// reasons are pinned here rather than left to a comment nobody re-reads.
    func testTheUserAgentKeepsTheTokensChromeItselfFreezes() {
        let userAgent = YouTubeIdentity.userAgent

        XCTAssertTrue(userAgent.contains("Chrome/150.0.0.0"),
                      "user agent reduction freezes everything after the major version, so the real build 150.1.92.141 "
                      + "would be less realistic here, not more")
        XCTAssertTrue(userAgent.contains("Mac OS X 10_15_7"),
                      "Chrome has reported Catalina on every Mac since Big Sur, whatever macOS is actually running")
        XCTAssertFalse(userAgent.contains("Brave"),
                       "Brave impersonates Chrome exactly, so a Brave token would name a browser no user agent names")
    }

    /// Headers go on every request, so the set may only contain headers that do not vary by what is
    /// being requested. A document `Accept` or a `Sec-Fetch-Mode` pinned across both the watch page
    /// and the caption fetch would describe a browser that does not exist.
    func testOnlyPerClientHeadersAreSent() {
        let perRequestHeaders = ["Accept", "Sec-Fetch-Mode", "Sec-Fetch-Dest", "Sec-Fetch-Site", "Referer"]

        for header in perRequestHeaders {
            XCTAssertNil(YouTubeIdentity.headers[header], "\(header) varies per request and cannot be pinned globally")
        }
    }
}
