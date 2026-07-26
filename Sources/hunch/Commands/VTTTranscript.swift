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
    /// instead of costing a single cue. The range check is only the backstop for whatever the digit
    /// checks let through, so it is set where an `Int` conversion is unquestionably safe rather than
    /// at the length of a plausible video - a 30 hour livestream is a real thing and not this
    /// function's business to have an opinion about.
    private static func seconds(from stamp: String) -> TimeInterval? {
        let parts = stamp.split(separator: ":", omittingEmptySubsequences: false)
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

        guard total.isFinite, (0..<(1000 * 3600)).contains(total) else { return nil }
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

        return normalize(decodeEntities(text)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The escapes WebVTT defines, plus the apostrophe spelling that caption files use.
    private static let namedEntities: [String: Character] = [
        "&lt;": "<",
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&nbsp;": "\u{00A0}",
        "&lrm;": "\u{200E}",
        "&rlm;": "\u{200F}",
        "&amp;": "&"
    ]

    /// Decodes every escape in a single left-to-right pass.
    ///
    /// One pass rather than one per escape, because any pass that re-reads what an earlier pass
    /// wrote will decode text nobody escaped. `&#38;lt;` spells an ampersand followed by the letters
    /// `lt;`, so decoding numbers first and names second turns it into `<`; swapping the order only
    /// moves the problem onto `&amp;#39;`. Appending each decoded character straight to the output
    /// and never looking at it again is what makes the whole class impossible.
    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var decoded = ""
        var index = text.startIndex

        while let start = text[index...].firstIndex(of: "&") {
            decoded += text[index..<start]

            // Bounded, so that an ampersand which starts nothing cannot send this scanning the rest
            // of the line for a semicolon belonging to something else entirely
            let window = text[start...].prefix(12)

            if let end = window.firstIndex(of: ";"), let character = character(forEscape: text[start...end]) {
                decoded.append(character)
                index = text.index(after: end)
            } else {
                // Not an escape after all, so the ampersand stays exactly as it was written
                decoded.append("&")
                index = text.index(after: start)
            }
        }

        return decoded + text[index...]
    }

    /// The character an `&...;` names, or nil if it names nothing.
    ///
    /// Numbered references are not part of WebVTT, but a transcript that came through a tool with an
    /// HTML step in it arrives full of numbered curly quotes, and left alone they render as
    /// themselves in the middle of a sentence.
    private static func character(forEscape escape: Substring) -> Character? {
        if let named = namedEntities[String(escape)] { return named }

        let body = escape.dropFirst().dropLast()
        guard body.first == "#" else { return nil }

        let digits = body.dropFirst()
        let isHex = digits.first == "x" || digits.first == "X"
        let value = isHex ? digits.dropFirst() : digits

        // Nil for a surrogate half or anything past the last code point, which leaves the reference
        // written out rather than inventing a replacement character for it
        // Checked to be digits before being read as a number, because `UInt32(_:radix:)` accepts a
        // leading sign - so `&#+39;` would otherwise decode to an apostrophe nobody wrote, which is
        // the same hole the timestamps had
        guard
            !value.isEmpty,
            value.allSatisfy({ isHex ? ($0.isASCII && $0.isHexDigit) : isDigit($0) }),
            let code = UInt32(value, radix: isHex ? 16 : 10),
            let scalar = Unicode.Scalar(code)
        else { return nil }

        return Character(scalar)
    }

    /// Flattens what a decoded escape can otherwise put in the middle of a markdown line.
    ///
    /// A no-break space is spelled `&nbsp;`, `&#160;` and `&#xA0;`, and letting the names and the
    /// numbers disagree would put two different byte sequences in content.md for one character - a
    /// grep that finds one spelling and misses the other across tens of thousands of files. They all
    /// become an ordinary space, which is what they look like in prose anyway.
    ///
    /// Line breaks matter more. The renderer writes one transcript line per markdown line and only
    /// substitutes `\n`, so a decoded carriage return, U+2028 or U+0085 would break the structure of
    /// the file from inside a cue. Every other control character goes for the same reason: none of
    /// them is a word anybody said, and all of them survive into the export otherwise. That means
    /// both control blocks - a numbered escape can name a C1 as easily as a C0.
    private static func normalize(_ text: String) -> String {
        guard needsFlattening(text) else { return text }

        var flattened = ""
        for character in text {
            if character.isNewline || character == "\u{00A0}" || character == "\t" {
                flattened.append(" ")
            } else if character.unicodeScalars.contains(where: isControl) {
                continue
            } else {
                flattened.append(character)
            }
        }
        return flattened
    }

    /// Asked of the scalars rather than the characters, which is the same question at a fraction of
    /// the cost: every newline this flattens is either a control scalar or one of the two separators
    /// named here, and the `\r\n` cluster is caught by either half of itself.
    private static func needsFlattening(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            isControl(scalar)
                || scalar.value == 0x00A0
                || scalar.value == 0x2028
                || scalar.value == 0x2029
        }
    }

    /// Both control blocks: C0 and delete, and the C1 range that a numbered escape can name just as
    /// easily - U+0085 is a line break that lives in it.
    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        return scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value)
    }
}
