# ytt: "Dismissed shelf" activity fails to parse

## Problem

When running `./fetch-youtube.sh` on a Google Takeout MyActivity.html file that contains "Dismissed shelf" YouTube activities, the parser throws:

```
Error: activityParseError(block: "...", reason: "Unsupported activity type: dismissed shelf")
```

Example invocation:

```
$ ./fetch-youtube.sh
Error: activityParseError(block: "<div class=\"outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp\"><div class=\"mdl-grid\"><div class=\"header-cell mdl-cell mdl-cell--12-col\"><p class=\"mdl-typography--title\">YouTube<br></p></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1\">Dismissed shelf<br>Jan 4, 2026, 1:48:04 PM CDT<br></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right\"></div><div class=\"content-cell mdl-cell mdl-cell--12-col mdl-typography--caption\"><b>Products:</b><br>&emsp;YouTube<br></div></div></div>", reason: "Unsupported activity type: dismissed shelf")
```

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  Dismissed shelf<br>
  Jan 4, 2026, 1:48:04 PM CDT<br>
</div>
```

Note: This activity has **no associated link** — it's just plain text "Dismissed shelf" followed by a timestamp. There is no video, channel, or other content linked.

## Root Cause

The action text is successfully extracted as `"dismissed shelf"` (lowercased) by the `actionNoLinkPattern` regex in `parseActivityBlock()` (`Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift` line 306). The error occurs at line 330 where `Activity.Action(rawValue: actionText)` returns `nil` because there is no matching enum case.

The `Action` enum in `Model+Public.swift` currently has:

```swift
case dismissed = "dismissed"
```

But the extracted action text is `"dismissed shelf"`, not `"dismissed"`. These are two different YouTube activity types:
- **"Dismissed"** — dismissing a single recommendation (already supported)
- **"Dismissed shelf"** — dismissing an entire shelf/row of recommendations on the YouTube home page

## Fix

One change needed in the `ytt` package:

### Add new `Action` case in `Model+Public.swift`

Add a case for the "dismissed shelf" activity:

```swift
case dismissedShelf = "dismissed shelf"
```

No other changes are needed because:
- The action text extraction already works (it's plain text before `<br>`, matching `actionNoLinkPattern`)
- The `Link` will correctly resolve to `.none` since there is no associated URL in the block
- The timestamp extraction will work normally
