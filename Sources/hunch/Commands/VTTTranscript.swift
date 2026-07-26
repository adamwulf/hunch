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
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Repairing bad bytes rather than refusing the file, so that nil keeps meaning exactly one
        // thing: there is no file here. A yt-dlp write interrupted mid-codepoint is an ordinary
        // enough accident across tens of thousands of folders, and rejecting the whole file for it
        // would throw away every cue that read fine and then report the video as one YouTube had
        // answered with silence - the opposite of what happened.
        return parse(String(decoding: data, as: UTF8.self))
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

            // A cue ends on a line with nothing on it. YouTube pads its cues with a line holding a
            // single space, and reading that alone as the terminator would drop the spoken line that
            // follows it - which in the first cue of every auto-generated file is the first thing
            // said in the video. That padding always arrives before the payload, so a blank-looking
            // line that arrives after some closes the cue: a file whose separators carry a space
            // would otherwise never close one, and every cue identifier in it would be rendered as
            // words somebody said.
            if line.isEmpty || (!payload.isEmpty && line.allSatisfy(\.isWhitespace)) {
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
    ///
    /// Every field is checked to be digits before it is read as a number, because `Double` and `Int`
    /// accept a great deal that is not a timestamp: `Double("nan")`, `Double("inf")` and
    /// `Double("0x1p10")` all succeed, `Int("-05")` succeeds and turns a malformed stamp into a
    /// negative time, and twenty digits of seconds overflow into 1e20. The renderer turns whatever
    /// comes back into an `Int`, which for a non-finite or oversized value is a trap rather than a
    /// thrown error - so one bad file would take down an export midway through 36,000 folders
    /// instead of costing a single cue. The range check is the backstop for the rest: a time no
    /// video could reach is not a timestamp, whatever it parsed as.
    private static func seconds(from stamp: String) -> TimeInterval? {
        let parts = stamp.split(separator: ":")
        guard (2...3).contains(parts.count), let last = parts.last else { return nil }

        var total: TimeInterval = 0
        for part in parts.dropLast() {
            guard isDigits(part), let value = Int(part) else { return nil }
            total = total * 60 + TimeInterval(value)
        }

        // WebVTT puts milliseconds after a dot and SRT after a comma. Files that went through a
        // converter carry the comma through often enough to be worth one replacement here rather
        // than a second parser.
        let secondsField = last.replacingOccurrences(of: ",", with: ".")
        guard
            secondsField.allSatisfy({ isDigit($0) || $0 == "." }),
            let secondsInMinute = Double(secondsField)
        else { return nil }

        total = total * 60 + secondsInMinute

        guard total.isFinite, (0..<(100 * 3600)).contains(total) else { return nil }
        return total
    }

    /// ASCII digits only: `Character.isNumber` is also true of digits from other scripts, which are
    /// not what a timestamp is written in.
    private static func isDigit(_ character: Character) -> Bool {
        return character.isASCII && character.isNumber
    }

    private static func isDigits(_ text: Substring) -> Bool {
        return !text.isEmpty && text.allSatisfy(isDigit)
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
            } else if character == ">" && insideTag {
                insideTag = false
            } else if !insideTag {
                // A closing bracket that never opened one is a character somebody typed. Broadcast
                // style captions open speaker turns with `>>`, and deleting those silently was worse
                // than leaving them: a browser renders a stray bracket as text too.
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

        // Numbered references first, so that the ampersand replacement below cannot turn a written
        // out `&amp;#39;` into an apostrophe somebody never typed
        return entities.reduce(decodeNumericReferences(text)) { decoded, entity in
            decoded.replacingOccurrences(of: entity.escape, with: entity.character)
        }
    }

    /// Decodes `&#8217;` and `&#x27;` style references.
    ///
    /// WebVTT does not define these, but caption files carry them anyway - a transcript that came
    /// through a tool with an HTML step in it arrives full of numbered curly quotes - and left alone
    /// they render as themselves in the middle of a sentence.
    private static func decodeNumericReferences(_ text: String) -> String {
        guard text.contains("&#") else { return text }

        var decoded = ""
        var rest = Substring(text)

        while let marker = rest.range(of: "&#") {
            let body = rest[marker.upperBound...]

            // Bounded, because an unterminated reference must not send this scanning the whole line
            // looking for a semicolon that belongs to something else entirely
            guard
                let end = body.prefix(12).firstIndex(of: ";"),
                let scalar = numericScalar(body[..<end])
            else {
                // Not a reference after all, so it stays exactly as it was written
                decoded += rest[..<marker.upperBound]
                rest = body
                continue
            }

            decoded += rest[..<marker.lowerBound]
            decoded.append(Character(scalar))
            rest = body[body.index(after: end)...]
        }

        return decoded + rest
    }

    private static func numericScalar(_ digits: Substring) -> Unicode.Scalar? {
        let isHex = digits.first == "x" || digits.first == "X"
        let value = isHex ? digits.dropFirst() : digits
        guard !value.isEmpty, let code = UInt32(value, radix: isHex ? 16 : 10) else { return nil }

        // Nil for a surrogate half or anything past the last code point, which leaves the reference
        // written out rather than inventing a replacement character for it
        return Unicode.Scalar(code)
    }
}
