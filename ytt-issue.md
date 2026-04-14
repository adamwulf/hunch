# ytt: "Dismissed a video that is no longer available" activity fails to parse

## Problem

When running `./fetch-youtube.sh` on a Google Takeout MyActivity.html file that contains a "Dismissed a video that is no longer available" YouTube activity, the parser throws:

```
Error: activityParseError(block: "...", reason: "Unsupported activity type: dismissed a video that is no longer available")
```

Example invocation:

```
$ ./fetch-youtube.sh
Error: activityParseError(block: "<div class=\"outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp\"><div class=\"mdl-grid\"><div class=\"header-cell mdl-cell mdl-cell--12-col\"><p class=\"mdl-typography--title\">YouTube<br></p></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1\">Dismissed a video that is no longer available<br>Dec 27, 2025, 9:42:00 PM CDT<br></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right\"></div><div class=\"content-cell mdl-cell mdl-cell--12-col mdl-typography--caption\"><b>Products:</b><br>&emsp;YouTube<br></div></div></div>", reason: "Unsupported activity type: dismissed a video that is no longer available")
```

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  Dismissed a video that is no longer available<br>
  Dec 27, 2025, 9:42:00 PM CDT<br>
</div>
```

Note: This activity has **no associated link** — it's plain text describing a dismissal of unavailable content, followed by a timestamp. There is no video, channel, or other content linked.

## Root Cause

The `actionNoLinkPattern` regex in `parseActivityBlock()` (`Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift` line 306) successfully extracts the full text `"dismissed a video that is no longer available"` (lowercased) as the action text. The error occurs at line 330 where `Activity.Action(rawValue: actionText)` returns `nil` because there is no matching enum case for this string.

This is similar to the already-handled case for `"Viewed a post that is no longer available"`, which is skipped at line 297:

```swift
guard !block.contains("Viewed a post that is no longer available") else {
    return nil
}
```

The "dismissed a video that is no longer available" activity describes a user dismissing a video that YouTube has since removed. Since the video no longer exists, there is no useful data to extract — no video ID, no title, no link. This is the same class of unavailable-content activity that is already being filtered out.

## Fix

One change needed in `parseActivityBlock()` in `Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift`:

### Expand the unavailable-content skip guard (line ~297)

Add a check for this new unavailable-content pattern alongside the existing one:

```swift
// Skip activities for unavailable content
guard !block.contains("Viewed a post that is no longer available"),
      !block.contains("Dismissed a video that is no longer available") else {
    return nil
}
```

No other changes are needed because:
- This follows the established pattern for handling unavailable-content activities (return `nil` to skip)
- No new `Action` enum case is required since the activity is skipped before action parsing
- The activity contains no useful data (no video ID, no link) so there is nothing to extract
