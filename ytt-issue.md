# ytt: Handle activities with no associated link (e.g., "Used Shorts creation tools")

## Problem

When running `hunch activity` on a Google Takeout MyActivity.html file that contains "Used Shorts creation tools" YouTube activities, the parser throws:

```
Error: activityParseError(block: "...", reason: "Could not extract action")
```

This happens for activities that describe tool usage rather than content interaction — they have no associated video, channel, post, or search URL.

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">Used Shorts creation tools<br>Apr 12, 2026, 11:00:07 AM CDT<br></div>
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right"></div>
```

Note: there is **no** `<a href="...">` link or `https://` URL in the content cell — just the action text followed by `<br>` and a timestamp.

## Root Cause

In `Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift`, `parseActivityBlock()` at line 297 uses this regex to extract the action text:

```swift
let actionPattern = #"<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">([^<]+?)(?:(?:https://|<a href="))"#
```

This regex **requires** the action text to be followed by either `https://` or `<a href="`. For "Used Shorts creation tools", the action text is followed by `<br>`, so the regex doesn't match at all, and the function throws `"Could not extract action"`.

Even if the regex were fixed, there are two more issues:

1. `Activity.Action` enum in `Model+Public.swift` has no case for "used shorts creation tools"
2. The link extraction (lines 316-329) requires at least one of: video, post, channel, playlist, or search link — but this activity has no link

## Fix

Three changes needed in the `ytt` package:

### 1. Add new `Action` case in `Model+Public.swift`

```swift
case usedShortsCreationTools = "used shorts creation tools"
```

### 2. Add a `Link` case for no-content activities in `Model+Public.swift`

```swift
case none  // Activity with no associated content (e.g., tool usage)
```

With a corresponding `url` implementation that returns nil or a sensible default.

### 3. Update `parseActivityBlock()` in `YouTubeTranscriptKit.swift`

The action extraction regex needs a second pattern that handles the no-link case. When the action text is followed by `<br>` instead of a URL, extract the action and set the link to `.none`.

Alternatively, the function could return `nil` for these activities (skip them), since they don't reference any video content.
