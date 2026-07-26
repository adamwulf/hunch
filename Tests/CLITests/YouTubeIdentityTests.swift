@testable import hunch
import XCTest
import YouTubeTranscriptKit

final class YouTubeIdentityTests: XCTestCase {
    private var originalConfiguration = YouTubeTranscriptKit.Configuration()

    // The kit's configuration is process wide, so it is captured rather than assumed empty and
    // handed back exactly as it was found
    override func setUp() {
        super.setUp()
        originalConfiguration = YouTubeTranscriptKit.configuration
    }

    override func tearDown() {
        YouTubeTranscriptKit.configure(originalConfiguration)
        super.tearDown()
    }

    func testInstallingTheIdentityReachesTheKit() {
        YouTubeIdentity.install()

        let headers = YouTubeTranscriptKit.configuration.additionalHeaders
        XCTAssertEqual(headers["User-Agent"], YouTubeIdentity.userAgent)
        XCTAssertEqual(headers["Accept-Language"], "en-US,en;q=0.9")
    }

    /// A canary rather than a behaviour test. Nothing installs this set globally any more - the
    /// downloader takes headers per request, so the Notion export path cannot inherit them and the
    /// compiler enforces that far better than a test could. What is worth pinning is the size: every
    /// header added here rides along on every request that passes the set on, which is the reasoning
    /// that kept Accept and the Sec-Fetch family out of it, and that reasoning is easy to forget
    /// while adding "just one more".
    func testTheHeaderSetStaysDeliberatelySmall() {
        XCTAssertEqual(YouTubeIdentity.headers.count, 2,
                       "adding a header here means sending it on every request, so weigh it against testOnlyPerClientHeadersAreSent")
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
