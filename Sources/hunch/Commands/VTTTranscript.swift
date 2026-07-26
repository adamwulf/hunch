import Foundation

/// One line of transcript as it will be rendered, whichever file it was read from.
///
/// Deliberately not `TranscriptMoment`. That type is what `transcript.json` encodes, so rendering
/// through a separate type is what makes it impossible to write VTT-derived text back out as hunch's
/// own fetch: the encoder never sees this struct. The two files have one writer each, and the
/// compiler holds them apart rather than a comment asking the next reader to.
struct TranscriptLine: Equatable {
    let start: TimeInterval
    let text: String
}

/// Where the words in a rendered content.md came from, or why there are none.
///
/// Written into the frontmatter of every file rather than only the ones with a transcript, because
/// the two kinds of nothing are what tell the videos worth another attempt from the ones already
/// answered, and an absent field cannot say which it is. The raw values are what get grepped across
/// tens of thousands of exported folders, so they are worth keeping stable.
///
/// Not spelled `none`: an enum case by that name collides with `Optional.none` at every use site
/// that ever wraps this type, and the resulting ambiguity is silent.
enum TranscriptSource: String {
    /// Rendered from `transcript.json`, hunch's own fetch through YouTubeTranscriptKit.
    case fetch = "hunch"
    /// Rendered from `transcript.vtt`, written beside it by yt-dlp, which reaches the auto-generated
    /// caption tracks that the web endpoint now answers with zero bytes.
    case ytDLP = "yt-dlp"
    /// Nothing to render: YouTube was asked and served nothing back, and no VTT has been pulled for
    /// this video either. A known answer rather than a gap, and what yt-dlp is worth pointing at.
    case knownEmpty = "none"
    /// Nothing to render and nothing has been established: no run has come back with an answer for
    /// this video, so the next one will ask again.
    case unfetched = "unfetched"
}

/// Reads WebVTT subtitle files into renderable lines.
///
/// Scoped to what yt-dlp writes rather than to the whole WebVTT grammar: cue timings, cue text, and
/// the rolling-window repetition that auto-generated captions are full of. Positioning, styling and
/// regions are all read past, since none of them survive into markdown anyway.
enum VTTTranscript {
    /// Reads a `.vtt` file, or nil if there is no readable file at that path.
    ///
    /// A file that parses to nothing comes back as an empty array rather than nil, so a caller can
    /// tell "no VTT here" from "a VTT with nothing in it".
    static func load(from url: URL) -> [TranscriptLine]? {
        guard
            let data = try? Data(contentsOf: url),
            let contents = String(data: data, encoding: .utf8)
        else { return nil }
        return parse(contents)
    }

    static func parse(_ contents: String) -> [TranscriptLine] {
        var rendered: [TranscriptLine] = []
        // Every line rendered so far, kept whole because the repetition below is matched against the
        // tail of it rather than against the previous cue alone
        var emitted: [String] = []
        var cueStart: TimeInterval?
        var payload: [String] = []

        /// Renders whatever the open cue added that has not been said already, then closes it.
        func flushCue() {
            defer {
                cueStart = nil
                payload = []
            }
            guard let start = cueStart else { return }
            let fresh = Array(payload.dropFirst(overlap(of: payload, with: emitted)))
            guard !fresh.isEmpty else { return }
            emitted.append(contentsOf: fresh)
            rendered.append(TranscriptLine(start: start, text: fresh.joined(separator: " ")))
        }

        for line in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            // A cue's payload may not contain an arrow, so this is the one unambiguous marker in the
            // format and worth trusting over tracking which kind of block we are inside
            if line.contains("-->") {
                flushCue()
                cueStart = startTime(ofTimingLine: line)
                continue
            }

            // Only a line with nothing at all on it ends a cue. YouTube pads its cues with a line
            // holding a single space, and reading that as the terminator would drop the spoken line
            // that follows it - which in the first cue of every auto-generated file is the first
            // thing said in the video.
            if line.isEmpty {
                flushCue()
                continue
            }

            // Outside a cue this is a header, a cue identifier, or the body of a NOTE, STYLE or
            // REGION block. None of them are words anyone said.
            guard cueStart != nil else { continue }

            let text = clean(line)
            if !text.isEmpty {
                payload.append(text)
            }
        }

        // Files pulled by yt-dlp routinely stop mid-cue with no closing blank line, so the last thing
        // said in the video is only rendered if EOF closes the cue too
        flushCue()

        return rendered
    }

    /// How many of the cue's leading lines have already been rendered.
    ///
    /// Auto-generated captions scroll a window of lines rather than replacing them, so each cue
    /// repeats its predecessor's last lines verbatim before adding its own. Matching the longest
    /// overlap rather than just the previous line keeps that working whatever height the window is,
    /// and anchoring it to the tail of what was rendered means a line that genuinely recurs later in
    /// the video is still rendered again.
    private static func overlap(of payload: [String], with emitted: [String]) -> Int {
        for length in stride(from: min(payload.count, emitted.count), through: 1, by: -1)
        where Array(emitted.suffix(length)) == Array(payload.prefix(length)) {
            return length
        }
        return 0
    }

    /// The start time from a cue's timing line, ignoring the end time and any cue settings after it.
    private static func startTime(ofTimingLine line: Substring) -> TimeInterval? {
        guard let start = line.components(separatedBy: "-->").first else { return nil }
        return seconds(from: start.trimmingCharacters(in: .whitespaces))
    }

    /// Reads `HH:MM:SS.mmm`, or `MM:SS.mmm` where WebVTT allows the hours to be left off.
    private static func seconds(from stamp: String) -> TimeInterval? {
        let parts = stamp.split(separator: ":")
        guard (2...3).contains(parts.count), let last = parts.last else { return nil }

        var total: TimeInterval = 0
        for part in parts.dropLast() {
            guard let value = Int(part) else { return nil }
            total = total * 60 + TimeInterval(value)
        }

        // WebVTT puts milliseconds after a dot and SRT after a comma. Files that went through a
        // converter carry the comma through often enough to be worth one replacement here rather
        // than a second parser.
        guard let secondsInMinute = Double(last.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return total * 60 + secondsInMinute
    }

    /// Strips a cue payload line down to the words it renders as.
    ///
    /// Auto-generated cues carry a timestamp tag before each word and wrap the word after it in a
    /// `c` tag, so most of such a line's characters are markup. Everything between angle brackets
    /// goes, which takes the speaker and styling tags with it. A raw `<` in the text would swallow
    /// the rest of the line, but WebVTT requires that be written as an escape, and the escapes below
    /// are decoded after the strip so an escaped bracket is never read as markup.
    private static func clean(_ line: Substring) -> String {
        var text = ""
        var insideTag = false

        for character in line {
            if character == "<" {
                insideTag = true
            } else if character == ">" {
                insideTag = false
            } else if !insideTag {
                text.append(character)
            }
        }

        return decodeEntities(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The escapes WebVTT defines, plus the two apostrophe spellings that show up in caption files.
    ///
    /// The ampersand is decoded last so that an escaped escape comes out as the literal text someone
    /// wrote rather than being decoded a second time into the character it names.
    private static let entities: [(escape: String, character: String)] = [
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", "\""),
        ("&#39;", "'"),
        ("&apos;", "'"),
        // Rendered as an ordinary space rather than U+00A0: this text is headed for markdown prose,
        // where the two look identical and only one of them can be searched for
        ("&nbsp;", " "),
        ("&lrm;", "\u{200E}"),
        ("&rlm;", "\u{200F}"),
        ("&amp;", "&")
    ]

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return entities.reduce(text) { decoded, entity in
            decoded.replacingOccurrences(of: entity.escape, with: entity.character)
        }
    }
}
