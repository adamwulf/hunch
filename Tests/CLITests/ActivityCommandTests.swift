@testable import hunch
import XCTest
import YouTubeTranscriptKit

final class ActivityCommandTests: XCTestCase {

    // MARK: - Asking again for empty transcripts

    /// The default is the whole point of the change: a transcript cached as empty is an answer
    /// YouTube already gave, and asking again spends requests against a rate limit to be told the
    /// same thing.
    func testEmptyTranscriptsAreTakenAtTheirWordByDefault() throws {
        let command = try ActivityCommand.parse(["MyActivity.html"])

        XCTAssertFalse(command.refetchEmptyTranscripts)
    }

    /// And the way back, for the day YouTube starts serving the tracks it refuses now. Without it,
    /// re-asking would mean finding and deleting every empty transcript.json by hand.
    func testEmptyTranscriptsCanBeAskedForAgain() throws {
        let command = try ActivityCommand.parse(["MyActivity.html", "--refetch-empty-transcripts"])

        XCTAssertTrue(command.refetchEmptyTranscripts)
    }

    // MARK: - Which transcript gets rendered

    func testHunchsOwnFetchIsRenderedWhenItHasWordsInIt() throws {
        let rendered = ActivityCommand.renderedTranscript(fetched: try moments(), vttAt: missingVTT())

        XCTAssertEqual(rendered.source, .fetch)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 1.5, text: "from the fetch")])
    }

    /// The reason any of this exists: 3,183 videos already have words on disk that hunch could not
    /// see, because nothing read the file yt-dlp wrote.
    func testTheVTTIsRenderedWhenTheFetchCameBackEmpty() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: vtt)

        XCTAssertEqual(rendered.source, .ytDLP)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 2, text: "from the vtt")])
    }

    func testTheVTTIsRenderedWhenNothingHasBeenFetchedAtAll() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: vtt)

        XCTAssertEqual(rendered.source, .ytDLP)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 2, text: "from the vtt")])
    }

    /// transcript.json is the file this tool is responsible for, so when it has content it is what
    /// gets rendered - the VTT is a fallback, not an upgrade.
    func testHunchsOwnFetchWinsOverAVTTSittingBesideIt() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: try moments(), vttAt: vtt)

        XCTAssertEqual(rendered.source, .fetch)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 1.5, text: "from the fetch")])
    }

    // MARK: - The two kinds of nothing

    /// The distinction the frontmatter exists to record. This video has been asked about and YouTube
    /// served nothing, so it is not waiting on another run - it is waiting on yt-dlp.
    func testAnEmptyFetchWithNoVTTReadsAsAKnownAnswer() {
        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: missingVTT())

        XCTAssertEqual(rendered.source, .knownEmpty)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// The other kind: nothing on disk, nothing answered, and the next run will ask again. Telling
    /// this apart from the case above at a glance is what makes 36,000 folders searchable.
    func testNoFetchAndNoVTTReadsAsNotYetAsked() {
        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: missingVTT())

        XCTAssertEqual(rendered.source, .unfetched)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// A VTT that parses to nothing is not a transcript, so it does not get to claim it rendered
    /// one. What is on disk is still an empty answer from YouTube.
    func testAVTTWithNoCuesDoesNotCountAsARenderedTranscript() throws {
        let vtt = try writeVTT(contents: "WEBVTT\nKind: captions\n")

        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: vtt)

        XCTAssertEqual(rendered.source, .knownEmpty)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// These four strings end up in the frontmatter of every exported folder, which is where they
    /// get searched. Renaming one silently splits a corpus in half, so they are pinned here.
    func testTheFrontmatterValuesStayStable() {
        XCTAssertEqual(TranscriptSource.fetch.rawValue, "hunch")
        XCTAssertEqual(TranscriptSource.ytDLP.rawValue, "yt-dlp")
        XCTAssertEqual(TranscriptSource.knownEmpty.rawValue, "none")
        XCTAssertEqual(TranscriptSource.unfetched.rawValue, "unfetched")
    }

    // MARK: - Helpers

    /// Decoded rather than constructed, because the kit keeps the memberwise initialiser to itself -
    /// and decoding is how the command comes by these anyway.
    private func moments() throws -> [TranscriptMoment] {
        let json = #"[{"start": 1.5, "duration": 2.0, "text": "from the fetch"}]"#
        return try JSONDecoder().decode([TranscriptMoment].self, from: Data(json.utf8))
    }

    private func writeVTT(contents: String = "WEBVTT\n\n00:00:02.000 --> 00:00:04.000\nfrom the vtt\n") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).vtt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func missingVTT() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("transcript.vtt")
    }
}
