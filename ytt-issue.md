# ytt: "Dismissed mix" activity type fails to parse

## Problem

When running `./fetch-youtube.sh` on a Google Takeout MyActivity.html file that contains a "Dismissed mix" YouTube activity, the parser throws:

```
Error: activityParseError(block: "...", reason: "Unsupported activity type: dismissed mix")
```

Example invocation:

```
$ ./fetch-youtube.sh
Error: activityParseError(block: "<div class=\"outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp\"><div class=\"mdl-grid\"><div class=\"header-cell mdl-cell mdl-cell--12-col\"><p class=\"mdl-typography--title\">YouTube<br></p></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1\">Dismissed mix<br>Apr 15, 2025, 1:02:25 AM CDT<br></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right\"></div><div class=\"content-cell mdl-cell mdl-cell--12-col mdl-typography--caption\"><b>Products:</b><br>&emsp;YouTube<br></div></div></div>", reason: "Unsupported activity type: dismissed mix")
```

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  Dismissed mix<br>
  Apr 15, 2025, 1:02:25 AM CDT<br>
</div>
```

Note: Unlike activities that contain video/channel links, this activity has **no links at all** — just the action text "Dismissed mix" followed by a timestamp. It's structurally similar to the existing `dismissed` and `dismissedShelf` actions but for YouTube Mix playlists (auto-generated playlists). The parsed `link` will be `.none`.

## Root Cause

The `actionNoLinkPattern` regex in `parseActivityBlock()` (`Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift` line 307) successfully extracts `"Dismissed mix"` as the action text before the `<br>` tag (since there's no link in this block, `actionWithLinkPattern` doesn't match, so it falls through to `actionNoLinkPattern`). After lowercasing and trimming, this becomes `"dismissed mix"`. The error occurs at line 331 where `Activity.Action(rawValue: actionText)` returns `nil` because there is no `case dismissedMix = "dismissed mix"` in the `Activity.Action` enum (`Sources/YouTubeTranscriptKit/Model+Public.swift` line 11).

The existing `Action` enum cases are: `watched`, `watchedStory`, `viewed`, `liked`, `disliked`, `subscribedTo`, `answered`, `votedOn`, `saved`, `searchedFor`, `dismissed`, `dismissedShelf`, `usedShortsCreationTools`, `shared`, `hyped`. There are already two similar "dismissed" variants (`dismissed` and `dismissedShelf`), but `"dismissed mix"` is not among them.

"Dismissed mix" is a YouTube action where the user dismissed a YouTube Mix — an auto-generated playlist of songs/videos. The link extraction logic will correctly fall through to `link = .none`, and the timestamp is in standard format. So the only missing piece is the enum case.

## Fix

One change needed in `Model+Public.swift` to add the new action type:

### Add `dismissedMix` case to `Activity.Action` enum (line ~26)

```swift
public enum Action: String, Codable {
    case watched = "watched"
    case watchedStory = "watched story"
    case viewed = "viewed"
    case liked = "liked"
    case disliked = "disliked"
    case subscribedTo = "subscribed to"
    case answered = "answered"
    case votedOn = "voted on"
    case saved = "saved"
    case searchedFor = "searched for"
    case dismissed = "dismissed"
    case dismissedShelf = "dismissed shelf"
    case dismissedMix = "dismissed mix"
    case usedShortsCreationTools = "used shorts creation tools"
    case shared = "shared"
    case hyped = "hyped"
}
```

No other changes are needed because:
- The `actionNoLinkPattern` regex already correctly extracts `"dismissed mix"` as the action text
- No link extraction is needed — all extractors will return nil and `link` will be `.none`
- The timestamp `"Apr 15, 2025, 1:02:25 AM CDT"` is in standard format and already parsed correctly
- This follows the same pattern as the existing `dismissedShelf` case — a "dismissed" variant with no associated content link
