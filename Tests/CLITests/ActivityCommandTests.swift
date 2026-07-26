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

    // MARK: - What is on disk

    func testAMissingTranscriptFileReadsAsMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("transcript.json")

        guard case .missing = ActivityCommand.cachedTranscript(at: missing, decoder: decoder) else {
            return XCTFail("a path with no file at it is not a cached transcript")
        }
    }

    /// Kept apart from missing on purpose: a refusal is written over a file that is not there and
    /// never over one that is. Collapsing the two destroyed half-written transcripts.
    func testAFileThatDoesNotDecodeReadsAsUnreadableRatherThanMissing() throws {
        let url = try writeJSON("{ this is not a transcript")

        guard case .unreadable = ActivityCommand.cachedTranscript(at: url, decoder: decoder) else {
            return XCTFail("a file that did not decode must not read as one that was never written")
        }
    }

    /// The line the whole change turns on. An empty file has to survive the round trip as an empty
    /// transcript, because reading it as "nothing cached" is what sends the video back to YouTube
    /// for an answer it already has.
    func testAnEmptyTranscriptFileSurvivesAsAnEmptyTranscript() throws {
        let url = try writeJSON("[]")

        XCTAssertEqual(ActivityCommand.cachedTranscript(at: url, decoder: decoder).moments?.count, 0)
    }

    func testAPopulatedTranscriptFileDecodes() throws {
        let url = try writeJSON(momentJSON)

        XCTAssertEqual(ActivityCommand.cachedTranscript(at: url, decoder: decoder).moments?.count, 1)
    }

    // MARK: - What the fetch builds on

    /// Without the flag, an empty answer is left standing and the video costs nothing.
    func testAnEmptyCacheIsLeftStandingByDefault() {
        XCTAssertEqual(ActivityCommand.transcriptToBuildOn(cached: .transcript([]), refetchEmpty: false)?.count, 0)
    }

    /// With it, the same file is deliberately forgotten so the video goes back down a fetch branch.
    func testAnEmptyCacheIsForgottenWhenAskingAgain() {
        XCTAssertNil(ActivityCommand.transcriptToBuildOn(cached: .transcript([]), refetchEmpty: true))
    }

    /// The flag only reopens empty answers. A transcript with words in it is never re-fetched.
    func testAPopulatedCacheIsKeptEvenWhenAskingAgain() throws {
        let cached = ActivityCommand.CachedTranscript.transcript(try moments())

        XCTAssertEqual(ActivityCommand.transcriptToBuildOn(cached: cached, refetchEmpty: true)?.count, 1)
    }

    func testAMissingCacheStaysMissing() {
        XCTAssertNil(ActivityCommand.transcriptToBuildOn(cached: .missing, refetchEmpty: false))
    }

    func testAnUnreadableCacheIsNothingToBuildOn() {
        XCTAssertNil(ActivityCommand.transcriptToBuildOn(cached: .unreadable, refetchEmpty: false))
    }

    // MARK: - What a failed fetch leaves behind

    func testTheTwoRefusalsAreToldApartFromEverythingElse() {
        guard
            case .noTracksListed = ActivityCommand.classifyFailure(YouTubeTranscriptKit.TranscriptError.noCaptionData),
            case .listedTracksWereEmpty
                = ActivityCommand.classifyFailure(YouTubeTranscriptKit.TranscriptError.noTranscriptData),
            case .unresolved = ActivityCommand.classifyFailure(URLError(.timedOut))
        else {
            return XCTFail("a refusal and a failure must not be classified the same way")
        }
    }

    /// A video whose player response lists no caption tracks is answered, not unlucky. Recording
    /// that is what stops it being asked again on every run for the rest of the corpus's life.
    func testAVideoWithNoCaptionsRecordsTheRefusal() {
        XCTAssertEqual(ActivityCommand.transcriptAfterFailure(.noTracksListed, cached: .missing)?.count, 0)
    }

    /// Same for a video whose listed tracks all came back empty, which is the zero-byte answer this
    /// change exists around - not because the captions are gone, but because asking over the web
    /// again changes nothing and costs two requests.
    func testAVideoWhoseTracksCameBackEmptyRecordsTheRefusal() {
        XCTAssertEqual(ActivityCommand.transcriptAfterFailure(.listedTracksWereEmpty, cached: .missing)?.count, 0)
    }

    /// The distinction that keeps this safe. A dropped connection says nothing about whether the
    /// video has captions, so recording an empty answer for it would cache a lie with no expiry.
    func testAnUnresolvedFailureLeavesTheCacheAlone() {
        XCTAssertNil(ActivityCommand.transcriptAfterFailure(.unresolved, cached: .missing))
    }

    /// And a refusal never overwrites words already on disk.
    func testARefusalNeverClobbersATranscriptAlreadyThere() throws {
        let cached = ActivityCommand.CachedTranscript.transcript(try moments())

        XCTAssertEqual(ActivityCommand.transcriptAfterFailure(.noTracksListed, cached: cached)?.count, 1)
    }

    /// The one that matters most: a transcript.json that is there but did not decode is never
    /// written over. It may be a half-written file from an interrupted run, and replacing it with an
    /// empty transcript would mark the video caption-free forever without its transcript ever having
    /// been read.
    func testARefusalIsNeverRecordedOverAFileThatDidNotDecode() {
        XCTAssertNil(ActivityCommand.transcriptAfterFailure(.noTracksListed, cached: .unreadable))
    }

    // MARK: - Counting what was written down

    /// A caption-parser break and a video with no captions arrive as the same error, and now that a
    /// run writes that down, one bad run would mark the whole corpus caption-free and then never
    /// fetch again. The count is what makes 30,000 refusals look different from 40.
    func testTheRunCountsWhatItWroteDown() {
        var tally = ActivityCommand.RefusalTally()
        XCTAssertNil(tally.summary, "a run that recorded nothing has nothing to report")

        tally.record(.noTracksListed, cached: .missing)
        tally.record(.listedTracksWereEmpty, cached: .missing)
        tally.record(.unresolved, cached: .missing)
        tally.recordCombinedFetch(cached: .missing)

        XCTAssertEqual(tally.counts.recorded, 3, "an unresolved failure is not a refusal and nothing was written for it")
        XCTAssertEqual(tally.summary?.contains("recorded 3 transcript refusals"), true)
    }

    /// The one population that does not settle by itself. A refusal over a file that did not decode
    /// is deliberately not written, so the video is asked about again on every run for good - and
    /// counting it apart is what stops that being silent.
    func testAVideoHeldBackByAnUnreadableFileIsCountedApart() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.noTracksListed, cached: .unreadable)

        XCTAssertEqual(tally.counts.blockedByUnreadableFile, 1)
        XCTAssertEqual(tally.counts.noTracksListed, 0, "nothing was written down for this video")
        XCTAssertEqual(tally.counts.recorded, 0, "a run that wrote nothing must not read as one that wrote something")
        XCTAssertEqual(tally.summary?.contains("recorded 0 transcript refusals"), true)
        XCTAssertEqual(tally.summary?.contains("1 more held back by a file that did not decode"), true)
    }

    /// The combined fetch reaches the same rule by a different door, and used to miss it: it counted
    /// a refusal that transcriptAfterFailure then declined to write, so a stranded video was filed
    /// under the bucket that says it settled - in the one place built to stop exactly that.
    func testACombinedFetchOverAnUnreadableFileIsHeldBackToo() {
        var tally = ActivityCommand.RefusalTally()

        tally.recordCombinedFetch(cached: .unreadable)

        XCTAssertEqual(tally.counts.blockedByUnreadableFile, 1)
        XCTAssertEqual(tally.counts.duringCombinedFetch, 0)
    }

    /// The count exists to make stranding visible, so it must never be the thing hiding it. One
    /// direction only: everything counted as recorded reached disk. The converse is not a rule -
    /// an unresolved failure writes the cache back unchanged without any refusal being recorded.
    func testNothingIsCountedAsRecordedThatIsNotWritten() {
        let caches: [ActivityCommand.CachedTranscript] = [.missing, .unreadable, .transcript([])]
        let failures: [ActivityCommand.FetchFailure] = [.noTracksListed, .listedTracksWereEmpty, .unresolved]

        for cached in caches {
            for failure in failures {
                var tally = ActivityCommand.RefusalTally()
                tally.record(failure, cached: cached)
                guard tally.counts.recorded > 0 else { continue }

                XCTAssertNotNil(ActivityCommand.transcriptAfterFailure(failure, cached: cached),
                                "counted \(failure) over \(cached) as recorded, but nothing was written")
            }
        }
    }

    /// A block rather than a running total. A break part way through 36,000 videos reads as 740,
    /// 840, 940 in a total, which is indistinguishable from ordinary accumulation.
    func testThePeriodicReportDescribesItsOwnBlock() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.noTracksListed, cached: .missing)
        XCTAssertEqual(tally.takeBlockSinceLastReport()?.contains("recorded 1 transcript refusals"), true)

        XCTAssertNil(tally.takeBlockSinceLastReport(), "a block with nothing in it says nothing")

        tally.record(.noTracksListed, cached: .missing)
        tally.record(.noTracksListed, cached: .missing)
        XCTAssertEqual(tally.takeBlockSinceLastReport()?.contains("recorded 2 transcript refusals"), true)

        XCTAssertEqual(tally.summary?.contains("recorded 3 transcript refusals"), true,
                       "the run total still counts everything, however it was reported along the way")
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

    /// With --refetch-empty-transcripts set, an empty transcript.json is read as nil on purpose so
    /// the video is asked about again. If that attempt then fails, nothing is written and the empty
    /// file is still sitting there - so the frontmatter has to describe the file, not the attempt.
    /// Saying `unfetched` over a folder whose transcript.json holds `[]` would have a grep for
    /// never-asked report a video that disk records as asked and answered.
    func testTheFrontmatterDescribesTheFileRatherThanTheAttempt() {
        // Exactly what the loop hands it: this run's fetch if there was one, otherwise what is
        // still sitting on disk
        let fetchThatFailed: [TranscriptMoment]? = nil
        let stillOnDisk: [TranscriptMoment] = []

        let rendered = ActivityCommand.renderedTranscript(fetched: fetchThatFailed ?? stillOnDisk, vttAt: missingVTT())

        XCTAssertEqual(rendered.source, .knownEmpty)
    }

    // MARK: - Helpers

    private let decoder = JSONDecoder()

    private let momentJSON = #"[{"start": 1.5, "duration": 2.0, "text": "from the fetch"}]"#

    /// Decoded rather than constructed, because the kit keeps the memberwise initialiser to itself -
    /// and decoding is how the command comes by these anyway.
    private func moments() throws -> [TranscriptMoment] {
        return try JSONDecoder().decode([TranscriptMoment].self, from: Data(momentJSON.utf8))
    }

    private func writeJSON(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
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
