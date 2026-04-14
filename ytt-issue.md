# ytt: Add support for "dismissed" activity type

## Problem

When running `hunch activity` on a Google Takeout MyActivity.html file that contains "Dismissed" YouTube activities, the parser throws:

```
Error: activityParseError(block: "...", reason: "Unsupported activity type: dismissed")
```

This happens when a user has dismissed a YouTube video recommendation. The HTML block looks like:

```html
<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">
  Dismissed <a href="https://www.youtube.com/watch?v=_VdXpecZf2o">VIDEO TITLE</a>
  ...
</div>
```

## Root Cause

In `Sources/YouTubeTranscriptKit/Model+Public.swift`, the `Activity.Action` enum has 10 cases but does not include `dismissed`:

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
}
```

In `YouTubeTranscriptKit.swift`, `parseActivityBlock()` extracts the action text, lowercases it, and tries `Activity.Action(rawValue: actionText)`. Since `"dismissed"` isn't a valid case, it throws the error.

## Fix

Add the missing case to the `Activity.Action` enum in `Sources/YouTubeTranscriptKit/Model+Public.swift`:

```swift
case dismissed = "dismissed"
```

No other changes are needed — the dismissed activity HTML contains a valid video URL (`<a href="https://www.youtube.com/watch?v=...">`), so the existing `extractVideoId()` link extraction logic handles it correctly.
