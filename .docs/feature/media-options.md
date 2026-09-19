# Media Options

Movie and episode detail pages and the video player share a Media Options dialog.
The launching button has a cog and a persistent source-media summary. Source
resolution and codecs describe the file, not negotiated transcoding output; the
audio summary follows the accepted track. Detail summaries retain their existing
640-pixel limit; playback summaries are capped at 600 pixels to leave room for
Cast and the centered transport controls.

## Navigation and pending selections

The dialog uses the Settings navigation pattern: categories on the left and a
content pane on the right. The category list leaves 24 pixels of breathing room
between its focus highlight and the vertical divider. Categories are Media Info, Video, Audio, Subtitles,
and Chapters, in that order. Audio appears for multiple tracks, Subtitles when
subtitle tracks exist, and Chapters when chapters exist. Media Info and Video
always appear. Opening selects Media Info and focuses navigation. Right or OK
enters the pane; Left returns to navigation. Back closes and applies changes.
There is no Done button or hint.

Media Info preserves source and stream details in the scrollable information
control. During playback it also includes clearly labeled playback diagnostics:
transcoding, resolved streams, and session identity. Video retains the four
existing playback modes and their descriptions. Subtitles includes Off, checked
when the initial selection has no subtitle track. An untouched detail-page
selection displays Off without staging a change; explicitly choosing Off still
returns a request to disable subtitles. Audio uses the marked default track,
or the first available track, when no explicit choice exists. Display defaults
are calculated separately from the original request and never stage edits.

Selections are staged locally. Moving between categories preserves them without
changing playback or the page. Closing publishes only selections that differ
from the initial snapshot; changing back to the original value produces no
change. An explicitly selected chapter is an action, including the chapter at
zero seconds. Merely focusing a chapter does not select it.

## Ownership and commit

`MediaOptionsDialog` extends Dialog and hosts MediaOptionsContent. The owner
supplies an `optionsContext` through the `mediaOptions` OverlayHost request.
It includes source data, option lists, initial selection, an opening generation,
and optional playback diagnostics. The dialog publishes `result` before the
normal close event, with optional `videoMode`, `audioStreamIndex`,
`subtitleStreamIndex`, and `chapter` fields. Missing fields mean unchanged;
subtitle index -1 explicitly means Off. Replacing/removing an overlay does not
invoke its user-close hook and therefore does not commit pending edits.

MainScene and PlaybackController only route. Movie and TVEpisode update their
owned selections together using the shared pure stream-change calculation and
refresh the summary. An explicit chapter launches
playback at that position with all final choices. Otherwise focus returns to the
summary button. Opening generations and item identity reject stale results.

VideoPlayer pauses while the dialog is open and records prior playing/paused
state, position, and request identity. Close schedules one combined commit after
the overlay is removed. Changes requiring playback resolution are merged into
one request, with the selected chapter position or captured position. Local
subtitle changes and chapter-only seeking avoid a restart. Removing burned-in
subtitles requires resolution; toggling captions cannot remove encoded pixels.
Accepted state is updated only by a local commit or accepted playback response.
Recovery during resolution retains the full pending selection. Accepted stream
indices are owned by ActivePlayback; recovery reads those same indices. Startup
pause/focus intent remains on the request through retries and is consumed only
when video starts. Deferred external-subtitle application is consumed once its
track becomes available and is invalidated by a newer local selection. Startup restores
the prior paused state and returns focus to the summary button. Teardown clears
pending commits, and request identity rejects results for another session.

The standalone media-information, playback-information, video-options, and
MediaStreamOptions wrappers and routes are retired. The generic OptionPicker
remains available for other features, including media actions. Cast, transport,
Last 5s, watched actions, and detail-page navigation remain separate.

## Verification

Rooibos coverage exercises category availability, pane focus, local selection,
change/revert, Off, chapter intent, Back commit, toolbar layout, combined restart,
local subtitle/seek changes, stale events, teardown, and paused state. Run the
full configured device suite as well as production validation and test build.
The `media-options.spec.mjs` RTA scenario exercises the configured episode,
remote navigation, scrolling, deferred changes, and restart restoration for both
playing and paused video. It captures detail and playback screenshots. Visual
verification must include long summary text, long information values, scrolling,
and both detail and playback toolbars.
