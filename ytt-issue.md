# ytt: Activity parse errors for unsupported activity formats

## Resolved: "Used Shorts creation tools" (no associated link)

**Status:** Fixed in current `main` — `usedShortsCreationTools` action case and `.none` link case both exist.

---

## Open: "Shared video" activity fails to parse

### Problem

When running `hunch activity` on a Google Takeout MyActivity.html file that contains "Shared video" YouTube activities, the parser throws:

```
Error: activityParseError(block: "...", reason: "Could not extract action")
```

Example invocation:

```
$ ./fetch-youtube.sh
Error: activityParseError(block: "<div class=\"outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp\">...Shared video...</div>", reason: "Could not extract action")
```

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  <a href="https://youtube.com/watch?v=91AJ0cpgLlQ&amp;si=YuAnMOTLcrxcDecZ">Shared video</a><br>
  Shared URL: https://youtube.com/watch?v=91AJ0cpgLlQ&amp;si=YuAnMOTLcrxcDecZ<br>
  <a href="https://youtube.com/watch?v=91AJ0cpgLlQ&amp;si=YuAnMOTLcrxcDecZ">How Anthropic uses Claude in Product Management</a><br>
  Mar 26, 2026, 11:57:04 PM CDT<br>
</div>
```

Note: the action text "Shared video" is **inside an anchor tag** (`<a href="...">Shared video</a>`) rather than being plain text before a link. This is different from all other activity types where the action text is plain text.

### Root Cause

In `Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift`, `parseActivityBlock()` at line 295 has two regex patterns for extracting action text:

```swift
let actionWithLinkPattern = #"<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">([^<]+?)(?:(?:https://|<a href="))"#
let actionNoLinkPattern = #"<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">([^<]+?)<br>"#
```

Both patterns use `([^<]+?)` to capture the action text, which requires plain text (no `<` characters). But for "Shared video", the content cell **starts with** `<a href="...">`, so there is no plain text to match before the `<` — both regexes fail, and the function throws `"Could not extract action"`.

Beyond the action extraction, there are two more issues:

1. **Missing `Action` case:** `Activity.Action` enum in `Model+Public.swift` has no case for `"shared video"` (or similar like `"shared"`)
2. **URL format mismatch:** The shared video URL uses `youtube.com/watch?v=...` (no `www.`), but `extractVideoId()` at line 361 requires `www.youtube.com/watch`:
   ```swift
   let anchorPattern = #"<a href="(?:https://)?www\.youtube\.com/watch\?v=([^"]+)">([^<]+)</a>"#
   ```
   This would fail to extract the video ID even after the action is fixed.

### Fix

Three changes needed in the `ytt` package:

#### 1. Add new `Action` case in `Model+Public.swift`

Add a case for sharing activities:

```swift
case sharedVideo = "shared video"
```

#### 2. Add a third action extraction pattern in `parseActivityBlock()` (`YouTubeTranscriptKit.swift`)

Add a regex that handles action text wrapped in an anchor tag. The new pattern should capture text from inside `<a href="...">ACTION TEXT</a>`:

```swift
let actionInLinkPattern = #"<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1"><a href="[^"]+">([^<]+)</a>"#
```

This should be tried as a third fallback after `actionWithLinkPattern` and `actionNoLinkPattern`, or potentially first since it's the most specific.

#### 3. Update `extractVideoId()` to handle URLs without `www.`

The anchor pattern and plain URL pattern in `extractVideoId()` both require `www.youtube.com`. The "Shared video" activity uses `youtube.com` without `www.`. Update the patterns to make `www.` optional:

```swift
// Anchor pattern: make www. optional
let anchorPattern = #"<a href="(?:https://)?(?:www\.)?youtube\.com/watch\?v=([^"]+)">([^<]+)</a>"#

// Plain URL pattern: make www. optional
let plainPattern = #"https://(?:www\.)?youtube\.com/watch\?v=([^<\s]+)"#
```

**Note:** The same `www.` issue may affect `extractPostId`, `extractChannelId`, `extractPlaylistId`, and `extractSearchQuery` — consider auditing all URL patterns for consistency.
