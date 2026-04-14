# ytt: "Hyped" activity type fails to parse

## Problem

When running `./fetch-youtube.sh` on a Google Takeout MyActivity.html file that contains a "Hyped" YouTube activity, the parser throws:

```
Error: activityParseError(block: "...", reason: "Unsupported activity type: hyped")
```

Example invocation:

```
$ ./fetch-youtube.sh
Error: activityParseError(block: "<div class=\"outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp\"><div class=\"mdl-grid\"><div class=\"header-cell mdl-cell mdl-cell--12-col\"><p class=\"mdl-typography--title\">YouTube<br></p></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1\">Hyped <a href=\"https://www.youtube.com/watch?v=6l7B7zjKyXo\">Pioneertown LiveStream</a><br><a href=\"https://www.youtube.com/channel/UCwbLD07XxWfEw0OIHZKM7lw\">The Tiny Chef Show</a><br>Nov 18, 2025, 4:06:40 AM CDT<br></div><div class=\"content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right\"></div><div class=\"content-cell mdl-cell mdl-cell--12-col mdl-typography--caption\"><b>Products:</b><br>&emsp;YouTube<br><b>Why is this here?</b><br>&emsp;This activity was saved to your Google Account because the following settings were on:&nbsp;YouTube watch history.&nbsp;You can control these settings &nbsp;<a href=\"https://myaccount.google.com/activitycontrols\">here</a>.</div></div></div>", reason: "Unsupported activity type: hyped")
```

The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  Hyped <a href="https://www.youtube.com/watch?v=6l7B7zjKyXo">Pioneertown LiveStream</a><br>
  <a href="https://www.youtube.com/channel/UCwbLD07XxWfEw0OIHZKM7lw">The Tiny Chef Show</a><br>
  Nov 18, 2025, 4:06:40 AM CDT<br>
</div>
```

Note: Unlike the previously-fixed "Dismissed a video that is no longer available" case, this activity **does** have an associated video link and channel link — it contains real, extractable data (video ID `6l7B7zjKyXo`, title "Pioneertown LiveStream", channel "The Tiny Chef Show").

## Root Cause

The `actionWithLinkPattern` regex in `parseActivityBlock()` (`Sources/YouTubeTranscriptKit/YouTubeTranscriptKit.swift` line 306) successfully extracts `"Hyped "` as the action text before the `<a href=` tag. After lowercasing and trimming, this becomes `"hyped"`. The error occurs at line 331 where `Activity.Action(rawValue: actionText)` returns `nil` because there is no `case hyped = "hyped"` in the `Activity.Action` enum (`Sources/YouTubeTranscriptKit/Model+Public.swift` line 11).

The existing `Action` enum cases are: `watched`, `watchedStory`, `viewed`, `liked`, `disliked`, `subscribedTo`, `answered`, `votedOn`, `saved`, `searchedFor`, `dismissed`, `dismissedShelf`, `usedShortsCreationTools`, `shared`. The `"hyped"` activity type is not among them.

"Hyped" appears to be a YouTube engagement action (similar to "liked" or "saved") where the user expressed excitement about a video. The activity follows the same structural pattern as `watched` or `liked` — action text followed by a video link and channel link — so the existing link extraction logic will work without changes.

## Fix

One change needed in `Model+Public.swift` to add the new action type:

### Add `hyped` case to `Activity.Action` enum (line ~25)

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
    case usedShortsCreationTools = "used shorts creation tools"
    case shared = "shared"
    case hyped = "hyped"
}
```

No other changes are needed because:
- The `actionWithLinkPattern` regex already correctly extracts `"hyped"` as the action text
- The video link and channel link are in standard format and already handled by `extractVideoId` and `extractChannelId`
- The timestamp is in standard format and already parsed correctly
- This is a real activity with extractable data (not an unavailable-content skip case)
