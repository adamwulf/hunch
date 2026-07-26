import Foundation
import YouTubeTranscriptKit

/// The HTTP identity hunch presents to YouTube.
///
/// `YouTubeTranscriptKit` ships no `User-Agent` of its own and takes an arbitrary header dictionary
/// rather than a user-agent knob, on the reasoning that only the consumer knows which identity is
/// coherent for it. This is hunch answering that question, in one place, for every command.
///
/// Identity is secondary to pacing. An unauthenticated client asking for watch pages by the tens of
/// thousands gets rate limited on the strength of its request rate no matter what it calls itself,
/// which is `FetchPacer`'s job. What identity buys is headroom: the default CFNetwork string names
/// an obviously non-browser client, and that is the cheapest possible thing for YouTube to weigh
/// when it decides who to throttle first.
enum YouTubeIdentity {
    /// Read out of Adam's own browser (Brave 150.1.92.141 on macOS) rather than composed by hand.
    ///
    /// Three tokens look wrong and are not. Correcting any of them makes this string less realistic,
    /// not more:
    ///
    /// - No `Brave` token appears, because Brave impersonates Chrome exactly as an anti
    ///   fingerprinting measure. There is nothing browser specific here to preserve.
    /// - The version is `150.0.0.0`, not the real build `150.1.92.141`. Chrome's user agent reduction
    ///   freezes everything after the major version, so every real Chrome 150 reports these zeroes.
    /// - The OS is `10_15_7`, not the macOS actually running. That is frozen too: Chrome has reported
    ///   Catalina since Big Sur shipped, on every Mac.
    ///
    /// This does need bumping now and then. A client still claiming Chrome 150 a year from now is
    /// its own distinguishing signature, which is the problem it was meant to avoid.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) "
        + "Chrome/150.0.0.0 Safari/537.36"

    /// Headers sent on every YouTube request.
    ///
    /// Deliberately short. These headers ride on `URLSessionConfiguration.httpAdditionalHeaders`, so
    /// every one of them goes on every request the kit makes, and only headers a browser sends
    /// identically regardless of what it is asking for belong in that set. `Accept` and the
    /// `Sec-Fetch-*` family are the counter examples: real Chrome sends a document `Accept` and
    /// `Sec-Fetch-Mode: navigate` when loading a watch page, and different values entirely when the
    /// page's own script goes back for the caption track. Pinning one value for both would fabricate
    /// a combination no browser produces, which is worse than leaving them off.
    ///
    /// `Accept-Language` is here because it is genuinely per client rather than per request, and
    /// because a request claiming to be Chrome while sending no language preference at all is the
    /// kind of internal inconsistency that is trivial to spot. The Chromium client hints
    /// (`sec-ch-ua` and friends) belong here for the same reason and are missing for a different one:
    /// their brand list includes a deliberately randomized "greased" entry that varies by build, and
    /// an invented value contradicts the user agent more loudly than a missing one. Adding them wants
    /// the real trio read out of the same browser this user agent came from.
    static let headers: [String: String] = [
        "User-Agent": userAgent,
        "Accept-Language": "en-US,en;q=0.9"
    ]

    /// Installs the identity on the session that fetches YouTube pages.
    ///
    /// Thumbnails need it too - a run pulls watch pages from youtube.com and the images those pages
    /// name from i.ytimg.com, and one host seeing Chrome while the other sees the URLSession default
    /// from the same IP moments later describes a client that does not exist. Those go out through
    /// `FileDownloader`, which is shared with the Notion export path, so they carry `headers` per
    /// request from the call site that knows it is talking to YouTube rather than being installed
    /// globally here. An export has no business claiming to be a browser to Notion.
    ///
    /// Safe to call once at startup and needs no ordering against the first fetch: `configure(_:)`
    /// rebuilds the session on the spot rather than at next use.
    static func install() {
        YouTubeTranscriptKit.configure(.init(additionalHeaders: headers))
    }
}
