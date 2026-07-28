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

        tally.record(.noTracksListed, cached: .missing, reconfirming: false)
        tally.record(.listedTracksWereEmpty, cached: .missing, reconfirming: false)
        tally.record(.unresolved, cached: .missing, reconfirming: false)
        tally.recordCombinedFetch(cached: .missing)

        XCTAssertEqual(tally.counts.recorded, 3, "an unresolved failure is not a refusal and nothing was written for it")
        XCTAssertEqual(tally.summary?.contains("recorded 3 transcript refusals"), true)
    }

    /// The one population that does not settle by itself. A refusal over a file that did not decode
    /// is deliberately not written, so the video is asked about again on every run for good - and
    /// counting it apart is what stops that being silent.
    func testAVideoHeldBackByAnUnreadableFileIsCountedApart() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.noTracksListed, cached: .unreadable, reconfirming: false)

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

    /// The count exists to make stranding visible, so it must never be the thing hiding it.
    ///
    /// Two properties, and the second is the one that actually broke. Counted-implies-written holds
    /// one way only, because an unresolved failure writes the cache back unchanged while recording
    /// nothing - a symmetric assertion would fail on that row. But both doors into the tally must
    /// also classify a given cache the same way as each other, and agreeing with the writer
    /// separately is weaker than agreeing between themselves: the combined fetch counted a refusal
    /// the writer then declined to write, and only mutual agreement catches that.
    func testBothWaysIntoTheTallyAgreeWithTheWriterAndWithEachOther() throws {
        let caches: [ActivityCommand.CachedTranscript] = [
            .missing, .unreadable, .transcript([]), .transcript(try moments())
        ]
        let failures: [ActivityCommand.FetchFailure] = [.noTracksListed, .listedTracksWereEmpty, .unresolved]

        for cached in caches {
            for failure in failures {
                var tally = ActivityCommand.RefusalTally()
                tally.record(failure, cached: cached, reconfirming: false)

                if tally.counts.recorded > 0 {
                    XCTAssertNotNil(ActivityCommand.transcriptAfterFailure(failure, cached: cached),
                                    "counted \(failure) over \(cached) as recorded, but nothing was written")
                }
            }

            var throughCombinedFetch = ActivityCommand.RefusalTally()
            throughCombinedFetch.recordCombinedFetch(cached: cached)

            var throughRecord = ActivityCommand.RefusalTally()
            throughRecord.record(.listedTracksWereEmpty, cached: cached, reconfirming: false)

            XCTAssertEqual(throughCombinedFetch.counts.recorded, throughRecord.counts.recorded,
                           "the two doors disagree about whether \(cached) was recorded")
            XCTAssertEqual(throughCombinedFetch.counts.blockedByUnreadableFile,
                           throughRecord.counts.blockedByUnreadableFile,
                           "the two doors disagree about whether \(cached) strands the video")
        }
    }

    /// A block rather than a running total. A break part way through 36,000 videos reads as 740,
    /// 840, 940 in a total, which is indistinguishable from ordinary accumulation.
    func testThePeriodicReportDescribesItsOwnBlock() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.noTracksListed, cached: .missing, reconfirming: false)
        XCTAssertEqual(tally.takeBlockSinceLastReport()?.contains("recorded 1 transcript refusals"), true)

        XCTAssertNil(tally.takeBlockSinceLastReport(), "a block with nothing in it says nothing")

        tally.record(.noTracksListed, cached: .missing, reconfirming: false)
        tally.record(.noTracksListed, cached: .missing, reconfirming: false)
        XCTAssertEqual(tally.takeBlockSinceLastReport()?.contains("recorded 2 transcript refusals"), true)

        XCTAssertEqual(tally.summary?.contains("recorded 3 transcript refusals"), true,
                       "the run total still counts everything, however it was reported along the way")
    }

    // MARK: - Which transcript gets rendered

    func testHunchsOwnFetchIsRenderedWhenItHasWordsInIt() throws {
        let rendered = ActivityCommand.renderedTranscript(fetched: try moments(), vttAt: missingVTT(), unavailable: false)

        XCTAssertEqual(rendered.source, .fetch)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 1.5, text: "from the fetch")])
    }

    /// The reason any of this exists: 3,183 videos already have words on disk that hunch could not
    /// see, because nothing read the file yt-dlp wrote.
    func testTheVTTIsRenderedWhenTheFetchCameBackEmpty() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: vtt, unavailable: false)

        XCTAssertEqual(rendered.source, .ytDLP)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 2, text: "from the vtt")])
    }

    func testTheVTTIsRenderedWhenNothingHasBeenFetchedAtAll() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: vtt, unavailable: false)

        XCTAssertEqual(rendered.source, .ytDLP)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 2, text: "from the vtt")])
    }

    /// transcript.json is the file this tool is responsible for, so when it has content it is what
    /// gets rendered - the VTT is a fallback, not an upgrade.
    func testHunchsOwnFetchWinsOverAVTTSittingBesideIt() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: try moments(), vttAt: vtt, unavailable: false)

        XCTAssertEqual(rendered.source, .fetch)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 1.5, text: "from the fetch")])
    }

    // MARK: - The two kinds of nothing

    /// The distinction the frontmatter exists to record. This video has been asked about and YouTube
    /// served nothing, so it is not waiting on another run - it is waiting on yt-dlp.
    func testAnEmptyFetchWithNoVTTReadsAsAKnownAnswer() {
        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: missingVTT(), unavailable: false)

        XCTAssertEqual(rendered.source, .knownEmpty)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// The other kind: nothing on disk, nothing answered, and the next run will ask again. Telling
    /// this apart from the case above at a glance is what makes 36,000 folders searchable.
    func testNoFetchAndNoVTTReadsAsNotYetAsked() {
        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: missingVTT(), unavailable: false)

        XCTAssertEqual(rendered.source, .unfetched)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// A VTT that parses to nothing is not a transcript, so it does not get to claim it rendered
    /// one. What is on disk is still an empty answer from YouTube.
    func testAVTTWithNoCuesDoesNotCountAsARenderedTranscript() throws {
        let vtt = try writeVTT(contents: "WEBVTT\nKind: captions\n")

        let rendered = ActivityCommand.renderedTranscript(fetched: [], vttAt: vtt, unavailable: false)

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
        XCTAssertEqual(TranscriptSource.videoUnavailable.rawValue, "unavailable")
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

        let rendered = ActivityCommand.renderedTranscript(fetched: fetchThatFailed ?? stillOnDisk, vttAt: missingVTT(), unavailable: false)

        XCTAssertEqual(rendered.source, .knownEmpty)
    }

    // MARK: - A video YouTube will not serve at all

    /// The default has to be trusting the marker, or it buys nothing: a video asked about again on
    /// every run is the loop this change exists to drain.
    func testARecordedVideoIsTrustedByDefault() throws {
        let command = try ActivityCommand.parse(["MyActivity.html"])

        XCTAssertFalse(command.recheckUnavailable)
    }

    /// And the appeal, for the video that gets un-privated or restored. A permanent answer with no
    /// way to clear it is not a cache, it is a verdict.
    func testARecordedVideoCanBeAskedAboutAgain() throws {
        let command = try ActivityCommand.parse(["MyActivity.html", "--recheck-unavailable"])

        XCTAssertTrue(command.recheckUnavailable)
    }

    /// s3cB-2Tm3ZM: no videoDetails, no microformat, no captions, and playabilityStatus ERROR. It
    /// used to be reported as a schema change, which is the opposite of the truth, and retried for
    /// ever at two requests a run.
    func testADeletedVideoIsClassifiedAsPermanentlyUnavailable() {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(status: "ERROR", reason: "Video unavailable")

        guard case .permanentlyUnavailable(let status, let reason) = ActivityCommand.classifyFailure(error) else {
            return XCTFail("a deleted video is an answer, not a parser bug")
        }
        XCTAssertEqual(status, "ERROR")
        XCTAssertEqual(reason, "Video unavailable")
    }

    /// A members-only video whose metadata does not decode at all reaches the same place. The
    /// ordinary members-only video does decode now and never gets here - see the view count test
    /// below - but the status is established as permanent either way.
    func testAMembersOnlyVideoIsClassifiedAsPermanentlyUnavailable() {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(status: "UNPLAYABLE", reason: nil)

        guard case .permanentlyUnavailable = ActivityCommand.classifyFailure(error) else {
            return XCTFail("UNPLAYABLE is established as permanent in the kit's fixtures")
        }
    }

    /// The one that matters most, and the reason this is an allowlist rather than "any
    /// videoUnavailable".
    ///
    /// YouTube sends LOGIN_REQUIRED both for a private video, which is permanent, and for its "Sign
    /// in to confirm you're not a bot" wall, which is a soft ban. That wall arrives as a 200 on a
    /// page nothing upstream recognises as a ban. Filing it permanently would write off every video
    /// fetched during that ban - thousands of live videos in one run, each with a file beside it
    /// saying do not ask again, and nothing left that would ever look.
    func testASignInWallIsNeverFiledAsPermanent() {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(
            status: "LOGIN_REQUIRED", reason: "Sign in to confirm you're not a bot")

        guard case .unresolved = ActivityCommand.classifyFailure(error) else {
            return XCTFail("a soft ban must be retried, not recorded as a dead video")
        }
    }

    /// A stream that has not started yet is as transient as anything gets.
    func testAnOfflineLiveStreamIsNotFiledAsPermanent() {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(status: "LIVE_STREAM_OFFLINE", reason: nil)

        guard case .unresolved = ActivityCommand.classifyFailure(error) else {
            return XCTFail("a stream that has not started is not a video that is gone")
        }
    }

    /// Unrecognised statuses default to retrying, which is the safe direction to be wrong in. The
    /// match is verbatim and case-sensitive: a status differing even in case is one this tool has
    /// never seen, and assuming it means what the uppercase one means is a guess.
    func testAStatusThisToolHasNotSeenIsRetriedRatherThanWrittenOff() {
        let unseen = ["SOMETHING_NEW", "error", "Unplayable", ""]

        for status in unseen {
            let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(status: status, reason: nil)

            guard case .unresolved = ActivityCommand.classifyFailure(error) else {
                return XCTFail("\(status) has never been established as permanent, so it must be retried")
            }
        }
    }

    // MARK: - What an unavailable video leaves behind

    /// The refusals record an empty transcript; this one must not, and the difference is what the
    /// empty file claims. It says YouTube was asked about captions and served nothing, which is the
    /// value content.md renders as the population worth pointing yt-dlp at. Nothing was asked here -
    /// the kit throws from the info parse, before any caption track is fetched - and yt-dlp cannot
    /// fetch a deleted video either.
    func testAnUnavailableVideoLeavesTheTranscriptSlotAlone() {
        let failure = ActivityCommand.FetchFailure.permanentlyUnavailable(status: "ERROR", reason: nil)

        XCTAssertNil(ActivityCommand.transcriptAfterFailure(failure, cached: .missing),
                     "an empty transcript here is an answer nobody ever received")
    }

    func testAnUnavailableVideoNeverClobbersWordsAlreadyOnDisk() throws {
        let failure = ActivityCommand.FetchFailure.permanentlyUnavailable(status: "ERROR", reason: nil)
        let cached = ActivityCommand.CachedTranscript.transcript(try moments())

        XCTAssertEqual(ActivityCommand.transcriptAfterFailure(failure, cached: cached)?.count, 1)
    }

    func testAnUnavailableVideoIsNeverRecordedOverAFileThatDidNotDecode() {
        let failure = ActivityCommand.FetchFailure.permanentlyUnavailable(status: "ERROR", reason: nil)

        XCTAssertNil(ActivityCommand.transcriptAfterFailure(failure, cached: .unreadable))
    }

    // MARK: - The marker

    func testOnlyAnEstablishedPermanentStatusWritesAMarker() {
        let failure = ActivityCommand.FetchFailure.permanentlyUnavailable(status: "UNPLAYABLE", reason: "Members only")

        guard case .gone(let marker) = ActivityCommand.unavailabilityAfterFailure(failure, now: recordedAt) else {
            return XCTFail("nothing written down means the video is asked about again every run")
        }
        XCTAssertEqual(marker, ActivityCommand.UnavailableVideo(
            status: "UNPLAYABLE", reason: "Members only", recordedAt: recordedAt))
    }

    /// The distinction the whole file turns on. A ban, a timeout or a 5xx says nothing about the
    /// video, so it must not file one as gone - and must not read as "this video is fine" either,
    /// which would delete markers all through a ban and hand the next run back everything this
    /// change exists to drain.
    func testAFailureThatProvesNothingNeitherWritesNorClearsAMarker() {
        let failures: [ActivityCommand.FetchFailure] = [.unresolved, .noTracksListed, .listedTracksWereEmpty]

        for failure in failures {
            XCTAssertEqual(ActivityCommand.unavailabilityAfterFailure(failure, now: recordedAt), .unchanged,
                           "\(failure) says nothing about whether the video still exists")
        }
    }

    func testTheMarkerSurvivesTheRoundTripToDisk() throws {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: "Video unavailable", recordedAt: recordedAt)

        let url = try writeMarker(marker)

        XCTAssertEqual(ActivityCommand.recordedUnavailability(at: url, decoder: markerDecoder), marker)
    }

    /// The shape on disk, pinned. Whatever else reads these folders reads this file, and a silent
    /// change to how the date is written would leave 37,000 markers that no longer decode - which
    /// fails quietly, by re-fetching everything, rather than loudly.
    func testTheMarkerOnDiskIsPlainISO8601() throws {
        let url = try writeJSON(#"{"status": "ERROR", "reason": "Video unavailable", "recordedAt": "2026-07-27T12:00:00Z"}"#)

        let recorded = ActivityCommand.recordedUnavailability(at: url, decoder: markerDecoder)

        XCTAssertEqual(recorded?.status, "ERROR")
        XCTAssertEqual(recorded?.recordedAt, ISO8601DateFormatter().date(from: "2026-07-27T12:00:00Z"))
    }

    /// The read direction alone proves nothing: a test with its own encoder passes under any
    /// self-consistent change. This asserts the bytes the command actually emits, so a change to the
    /// date strategy fails here rather than silently orphaning every marker already on disk.
    func testTheMarkerHunchWritesIsPlainISO8601() throws {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        let written = String(decoding: try markerEncoder.encode(marker), as: UTF8.self)

        XCTAssertTrue(written.contains("\"recordedAt\" : \"2026-07-28T12:00:00Z\""), written)
    }

    func testAMissingMarkerReadsAsNothingRecorded() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("unavailable.json")

        XCTAssertNil(ActivityCommand.recordedUnavailability(at: missing, decoder: markerDecoder))
    }

    /// The opposite of how transcript.json is treated, on purpose. A half-written transcript holds
    /// words no run may ever fetch again, so it is never overwritten; this file holds nothing that
    /// cannot be learned again by asking, so a corrupt one costs a fetch and is replaced.
    func testAMarkerThatDoesNotDecodeReadsAsNothingRecordedAndIsAskedAgain() throws {
        let url = try writeJSON("{ this is not a marker")

        XCTAssertNil(ActivityCommand.recordedUnavailability(at: url, decoder: markerDecoder))
    }

    func testARecordedVideoIsSkippedWithoutARequest() {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertEqual(ActivityCommand.unavailabilityToTrust(recorded: marker, recheck: false), marker)
    }

    func testRecheckingForgetsTheMarkerSoTheVideoIsAskedAgain() {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertNil(ActivityCommand.unavailabilityToTrust(recorded: marker, recheck: true))
    }

    /// Both passes of the loop, in order, for the video this change exists for. The first learns and
    /// writes; the second reads and never reaches a fetch branch at all.
    func testADeletedVideoIsRecordedOnceAndThenCostsNothing() throws {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(status: "ERROR", reason: "Video unavailable")
        let failure = ActivityCommand.classifyFailure(error)

        guard case .gone(let marker) = ActivityCommand.unavailabilityAfterFailure(failure, now: recordedAt) else {
            return XCTFail("the first pass has to write something down or the second repeats it")
        }
        XCTAssertNil(ActivityCommand.transcriptAfterFailure(failure, cached: .missing))

        let url = try writeMarker(marker)
        let recorded = ActivityCommand.recordedUnavailability(at: url, decoder: markerDecoder)

        XCTAssertEqual(ActivityCommand.unavailabilityToTrust(recorded: recorded, recheck: false), marker,
                       "the second pass must skip this video without spending a request on it")
    }

    /// The same two passes for a soft ban, which must leave no trace anywhere: nothing recorded, the
    /// cache untouched, and no marker to stop the next run trying again.
    func testASignInWallLeavesNothingBehindAtAll() {
        let error = YouTubeTranscriptKit.TranscriptError.videoUnavailable(
            status: "LOGIN_REQUIRED", reason: "Sign in to confirm you're not a bot")
        let failure = ActivityCommand.classifyFailure(error)

        var tally = ActivityCommand.RefusalTally()
        tally.record(failure, cached: .missing, reconfirming: false)

        XCTAssertNil(ActivityCommand.transcriptAfterFailure(failure, cached: .missing),
                     "an empty transcript recorded during a ban is a lie with no expiry")
        XCTAssertEqual(ActivityCommand.unavailabilityAfterFailure(failure, now: recordedAt), .unchanged,
                       "a marker written during a ban writes off a live video and nothing ever looks again")
        XCTAssertEqual(tally.counts.total, 0, "nothing was written, so nothing may be counted as written")
    }

    // MARK: - Counting videos written off

    /// Its own count, not folded into the refusals. Each is a tripwire for a different break - a
    /// caption parser that stopped working, an allowlist that started writing off live videos - and
    /// folding either into the other would blind both.
    func testVideosWrittenOffAreCountedApartFromTranscriptRefusals() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.noTracksListed, cached: .missing, reconfirming: false)
        tally.record(.permanentlyUnavailable(status: "ERROR", reason: nil), cached: .missing, reconfirming: false)

        XCTAssertEqual(tally.counts.permanentlyUnavailable, 1)
        XCTAssertEqual(tally.counts.recorded, 1, "a video that is gone is not a video whose captions were refused")
        XCTAssertEqual(tally.summary?.contains("1 newly recorded as permanently unavailable"), true)
    }

    /// A transcript refusal over a file that did not decode is held back and the video strands. A
    /// video written off does not, because what settles it is the marker, which is written whatever
    /// transcript.json holds - so filing it with the population that never drains would misreport
    /// both of them.
    func testAVideoWrittenOffIsNotStrandedByAFileThatDidNotDecode() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.permanentlyUnavailable(status: "ERROR", reason: nil), cached: .unreadable, reconfirming: false)

        XCTAssertEqual(tally.counts.permanentlyUnavailable, 1)
        XCTAssertEqual(tally.counts.blockedByUnreadableFile, 0, "the marker settles this video, not transcript.json")
    }

    /// Counted as written off implies something was written to say so - for every state
    /// transcript.json can be in, since the marker does not depend on it.
    func testWritingAVideoOffIsAlwaysBackedByAMarker() throws {
        let caches: [ActivityCommand.CachedTranscript] = [
            .missing, .unreadable, .transcript([]), .transcript(try moments())
        ]
        let failure = ActivityCommand.FetchFailure.permanentlyUnavailable(status: "ERROR", reason: nil)

        for cached in caches {
            var tally = ActivityCommand.RefusalTally()
            tally.record(failure, cached: cached, reconfirming: false)

            guard case .gone = ActivityCommand.unavailabilityAfterFailure(failure, now: recordedAt) else {
                return XCTFail("counted a video as written off over \(cached), but nothing was written to say so")
            }
            XCTAssertEqual(tally.counts.permanentlyUnavailable, 1, "over \(cached)")
        }
    }

    /// Newly-recorded is the tripwire; skipped is the evidence the queue is draining. Once a bad run
    /// has written thousands of markers, every run after it skips those same thousands, so folding
    /// the two together would bury each day's spike under a permanent baseline.
    func testSkippedVideosAreCountedApartFromNewlyRecordedOnes() {
        var tally = ActivityCommand.RefusalTally()

        tally.recordSkippedAsUnavailable()
        tally.recordSkippedAsUnavailable()

        XCTAssertEqual(tally.counts.skippedAsUnavailable, 2)
        XCTAssertEqual(tally.counts.permanentlyUnavailable, 0)
        XCTAssertEqual(tally.counts.recorded, 0)
        XCTAssertEqual(tally.summary?.contains("2 skipped as already recorded unavailable"), true)
    }

    /// The spike has to be visible while the run is still going. A misclassified ban that only shows
    /// up in the final summary has already written every marker by then.
    func testThePeriodicBlockReportsVideosWrittenOff() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.permanentlyUnavailable(status: "ERROR", reason: nil), cached: .missing, reconfirming: false)
        XCTAssertEqual(tally.takeBlockSinceLastReport()?.contains("1 newly recorded"), true)

        XCTAssertNil(tally.takeBlockSinceLastReport(), "a block with nothing in it says nothing")

        tally.record(.permanentlyUnavailable(status: "UNPLAYABLE", reason: nil), cached: .missing, reconfirming: false)
        tally.recordSkippedAsUnavailable()
        let block = tally.takeBlockSinceLastReport()

        XCTAssertEqual(block?.contains("1 newly recorded"), true)
        XCTAssertEqual(block?.contains("1 skipped as already recorded"), true)
        XCTAssertEqual(tally.summary?.contains("2 newly recorded"), true,
                       "the run total still counts everything, however it was reported along the way")
    }

    // MARK: - The third kind of nothing

    /// A written-off video must not land in either existing bucket. `none` names the videos yt-dlp is
    /// worth pointing at, and yt-dlp cannot fetch a deleted one; `unfetched` promises the next run
    /// will ask, and no run will.
    func testAGoneVideoSaysSoRatherThanClaimingYouTubeAnsweredWithSilence() {
        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: missingVTT(), unavailable: true)

        XCTAssertEqual(rendered.source, .videoUnavailable)
        XCTAssertTrue(rendered.lines.isEmpty)
    }

    /// Checked after the VTT, not before it. Words yt-dlp pulled before the video was deleted are
    /// still the words this video had, and are worth rendering.
    func testAVTTPulledBeforeTheVideoWentAwayStillWins() throws {
        let vtt = try writeVTT()

        let rendered = ActivityCommand.renderedTranscript(fetched: nil, vttAt: vtt, unavailable: true)

        XCTAssertEqual(rendered.source, .ytDLP)
        XCTAssertEqual(rendered.lines, [TranscriptLine(start: 2, text: "from the vtt")])
    }

    /// content.md describes the folder it sits in, so what it says has to be derived from what the
    /// writes are about to leave there - not from what this run happened to attempt.
    func testTheFrontmatterDescribesTheMarkerThatWillBeOnDisk() {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertTrue(ActivityCommand.isUnavailableAfterRun(.gone(marker), recorded: nil),
                      "a marker written by this run is on disk by the time content.md is rendered")
        XCTAssertFalse(ActivityCommand.isUnavailableAfterRun(.available, recorded: marker),
                       "a marker this run deleted is not")
        XCTAssertTrue(ActivityCommand.isUnavailableAfterRun(.unchanged, recorded: marker),
                      "a run that learned nothing leaves what was already recorded standing")
        XCTAssertFalse(ActivityCommand.isUnavailableAfterRun(.unchanged, recorded: nil))
    }

    // MARK: - Asking again actually asks

    /// Forgetting the marker only removes the short-circuit; the branches below still key off what is
    /// cached. Without forgetting the info too, a marked video holding both files would never reach a
    /// fetch, so its marker could never be re-confirmed or cleared - a verdict with no appeal, which
    /// is the trap the flag exists to prevent.
    func testRecheckingForgetsTheCachedInfoSoTheVideoReachesAFetch() throws {
        let info = try cachedInfo()
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertNil(ActivityCommand.infoToBuildOn(cached: info, recorded: marker, recheck: true),
                     "a marked video has to reach a fetch branch or the flag asks nothing")
    }

    /// And it is scoped to marked videos, so the flag costs nothing for the rest of the corpus.
    func testRecheckingLeavesUnmarkedVideosAlone() throws {
        let info = try cachedInfo()

        XCTAssertNotNil(ActivityCommand.infoToBuildOn(cached: info, recorded: nil, recheck: true))
        XCTAssertNotNil(ActivityCommand.infoToBuildOn(cached: info, recorded: nil, recheck: false))
    }

    func testWithoutTheFlagACachedInfoIsAlwaysBuiltOn() throws {
        let info = try cachedInfo()
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertNotNil(ActivityCommand.infoToBuildOn(cached: info, recorded: marker, recheck: false))
    }

    // MARK: - Re-confirming is not learning

    /// recordedAt is the only key that scopes a batch of markers to the run that wrote them, and it
    /// is the field no later run can recover. A recheck that finds the video still gone must not
    /// restamp it - otherwise the command an operator runs to investigate a suspect batch is the
    /// command that destroys the evidence.
    func testARecheckThatChangesNothingDoesNotRewriteTheMarker() {
        let onDisk = ActivityCommand.UnavailableVideo(status: "ERROR", reason: "Video unavailable", recordedAt: recordedAt)
        let learnedAgain = ActivityCommand.UnavailableVideo(
            status: "ERROR", reason: "Video unavailable", recordedAt: recordedAt.addingTimeInterval(86_400))

        XCTAssertTrue(learnedAgain.saysTheSameAs(onDisk), "nothing was learned, so nothing should be rewritten")
        XCTAssertTrue(ActivityCommand.isReconfirmation(.gone(learnedAgain), recorded: onDisk))
    }

    /// YouTube's prose is not the verdict. It gets reworded, localized, and renamed as membership
    /// tiers are renamed, and none of that means the video's status changed - so comparing it would
    /// let a copy edit on YouTube's side restamp recordedAt across the whole corpus and report every
    /// marker as newly written off, which is the one shape reserved for a misclassified ban.
    func testRewordedProseIsStillTheSameVerdict() {
        let onDisk = ActivityCommand.UnavailableVideo(
            status: "UNPLAYABLE", reason: "This video is available to members of this channel", recordedAt: recordedAt)
        let reworded = ActivityCommand.UnavailableVideo(
            status: "UNPLAYABLE", reason: "Join this channel to get access", recordedAt: recordedAt)

        XCTAssertTrue(reworded.saysTheSameAs(onDisk), "the status is the verdict; the reason is prose for a human")
        XCTAssertTrue(ActivityCommand.isReconfirmation(.gone(reworded), recorded: onDisk),
                      "nothing was learned, so recordedAt must survive")
    }

    /// A status that changed is news, and gets written.
    func testAStatusThatChangedIsWrittenDown() {
        let onDisk = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)
        let nowMembersOnly = ActivityCommand.UnavailableVideo(status: "UNPLAYABLE", reason: nil, recordedAt: recordedAt)

        XCTAssertFalse(nowMembersOnly.saysTheSameAs(onDisk))
        XCTAssertFalse(ActivityCommand.isReconfirmation(.gone(nowMembersOnly), recorded: onDisk),
                       "a different status is a different verdict, and gets written down")
        XCTAssertFalse(ActivityCommand.isReconfirmation(.gone(nowMembersOnly), recorded: nil),
                       "a video with no marker at all is always news")
    }

    func testOnlyAMarkerCanBeAReconfirmation() {
        let marker = ActivityCommand.UnavailableVideo(status: "ERROR", reason: nil, recordedAt: recordedAt)

        XCTAssertFalse(ActivityCommand.isReconfirmation(.unchanged, recorded: marker))
        XCTAssertFalse(ActivityCommand.isReconfirmation(.available, recorded: marker))
    }

    /// The count has to follow the write. A recheck run over the whole corpus re-confirms thousands
    /// of videos, and reporting those as newly written off would raise the exact alarm the tally
    /// exists to raise - every single time the flag is used.
    func testAReconfirmationIsNotCountedAsANewWriteOff() {
        var tally = ActivityCommand.RefusalTally()

        tally.record(.permanentlyUnavailable(status: "ERROR", reason: nil), cached: .missing, reconfirming: true)

        XCTAssertEqual(tally.counts.reconfirmedUnavailable, 1)
        XCTAssertEqual(tally.counts.permanentlyUnavailable, 0, "nothing new was learned and nothing was rewritten")
        XCTAssertEqual(tally.summary?.contains("1 confirmed still unavailable"), true)
        XCTAssertEqual(tally.summary?.contains("newly recorded"), false)
    }

    /// Once markers exist nearly every block skips something, so the refusal sentence would print
    /// four zeroes on every report for the rest of the corpus's life - burying the number it exists
    /// to make jump out.
    func testABlockWithNoRefusalsDoesNotSpellOutFourZeroes() {
        var tally = ActivityCommand.RefusalTally()

        tally.recordSkippedAsUnavailable()

        XCTAssertEqual(tally.summary?.contains("recorded no transcript refusals"), true)
        XCTAssertEqual(tally.summary?.contains("0 with no tracks listed"), false)
        XCTAssertEqual(tally.summary?.contains("1 skipped as already recorded unavailable"), true)
    }

    // MARK: - The half that needed no change

    /// smpLJS_QZg8: a members-only video, whose videoDetails is complete except for viewCount because
    /// YouTube does not publish one. That single absent field used to discard the title, channel,
    /// duration and thumbnails with it.
    ///
    /// The parse that fixed it is the kit's and is pinned there. What is pinned here is hunch's own
    /// round trip: a nil view count costs the views line in the frontmatter and nothing else, through
    /// the exact transformation the loop applies before writing info.json.
    func testAMembersOnlyVideoKeepsEverythingButItsViewCount() throws {
        let json = """
        {
          "videoId": "smpLJS_QZg8",
          "title": "A members-only video",
          "channelId": "UC1234567890",
          "channelName": "Some Channel",
          "duration": 754,
          "thumbnails": [{"url": "https://example.com/t.jpg", "width": 1280, "height": 720}]
        }
        """

        let stored = try decoder.decode(VideoInfo.self, from: Data(json.utf8)).withoutTranscript()

        XCTAssertNil(stored.viewCount, "YouTube does not publish a view count for a members-only video")
        XCTAssertEqual(stored.title, "A members-only video")
        XCTAssertEqual(stored.channelName, "Some Channel")
        XCTAssertEqual(stored.channelId, "UC1234567890")
        XCTAssertEqual(stored.duration, 754)
        XCTAssertEqual(stored.thumbnails?.count, 1)
    }

    // MARK: - Helpers

    private let decoder = JSONDecoder()

    /// Whole seconds, because the marker's date goes through ISO-8601 on the way to disk and back,
    /// and a Date() with fractional seconds does not survive that round trip.
    private let recordedAt = Date(timeIntervalSince1970: 1_785_240_000)

    /// The command's own pair, not a copy of it. A test that built a matching encoder would pass
    /// under any self-consistent change to the real one - which is precisely the change that would
    /// leave every marker already on disk undecodable.
    private let markerEncoder = ActivityCommand.artifactEncoder()
    private let markerDecoder = ActivityCommand.artifactDecoder()

    /// Decoded rather than constructed, for the same reason `moments()` is: the kit keeps the
    /// memberwise initialiser to itself, and decoding is how the command comes by these anyway.
    private func cachedInfo() throws -> VideoInfo {
        return try decoder.decode(VideoInfo.self, from: Data(#"{"videoId": "abc", "title": "A video"}"#.utf8))
    }

    private func writeMarker(_ marker: ActivityCommand.UnavailableVideo) throws -> URL {
        return try writeJSON(String(decoding: markerEncoder.encode(marker), as: UTF8.self))
    }

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
