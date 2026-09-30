# Automatic subtitles

Starfin follows Jellyfin's DefaultSubtitleStreamIndex when the viewer has not
chosen a track. Jellyfin owns language/mode rules and remembered selections.
Current user → Subtitles can edit Jellyfin's account mode and language through
saving pending choices when Settings closes; see [account subtitle settings](account-subtitle-settings.md).
The local per-account subtitle burn-in preference is independent. Starfin does not
report subtitle indices for per-title persistence.

## Selection and delivery

Playback requests retain subtitleStreamIndex as user intent: absent or -2 is
automatic, -1 is explicit Off, and a nonnegative index is a manual track.
resolvedSubtitleStreamIndex records the accepted track for same-title restarts
and recovery, independently of intent. VideoPlayer owns this accepted state.
Audio changes clear the resolved value; automatic intent asks Jellyfin again.
New-title queue requests carry neither index, so each title gets its own default.
Movie and episode detail pages retain manual intent when playback closes.

VideoPlaybackInfoTask omits SubtitleStreamIndex for unresolved automatic requests.
It validates the selected source's DefaultSubtitleStreamIndex against subtitle
streams; missing, negative, or unavailable indices mean Off. A selected subtitle
triggers exactly one follow-up PlaybackInfo request with the resolved index and
existing delivery policy. The task reuses the returned media source and opened
LiveStreamId, disabling AutoOpenLiveStream when a live stream is already open.
The follow-up preserves explicit audio, or uses the returned DefaultAudioStreamIndex
when it identifies an audio track, falling back to the file default otherwise.
Only the final result is published, including its URL, session and stream metadata. Follow-up failure, source changes, or removal
of the chosen track fail resolution instead of starting the discovery URL.
On negotiation failure, the task attempts to close a live stream acquired during
discovery before publishing the error. Caller-owned streams remain open. Cleanup
has a five-second timeout; cleanup failure is logged and preserves the original
playback error. This does not add cancellation cleanup for a forcibly stopped task.
Audio transcode and explicit-selection logging falls back to a general message
when stream metadata is absent, without changing playback negotiation.
Request identity prevents obsolete responses from being accepted by VideoPlayer.
No local language/mode rules or playback-time user-configuration refresh are needed.

## Media options

Detail pages always offer Jellyfin Account Default when subtitle tracks exist,
including after manual Off or track choices, so viewers can return to automatic.
Media-options context receives subtitle intent and optional resolved selection
separately. The active player shows
the actual track or Off, but opening/closing options without edits keeps automatic
intent. Choosing the currently displayed automatic track explicitly makes it
manual. Pauses, seeks, video-mode changes, and recovery preserve the accepted
track; each new title resolves independently through either queue advancement or
MainScene's normal launch/Up Next/deep-link route.

## Verification

External subtitle startup decides whether to disable captions from the resolved
playback response before assigning Video content. Track availability may notify
synchronously during assignment or later; a successful selection consumes the
pending URL without startup turning captions off again. An unmatched notification
retains the pending URL until the requested track becomes available.

Task tests cover both requests, burn-in modes, live identity reuse, invalid
server defaults, explicit selections, and failed or inconsistent follow-ups.
Player/detail/menu tests cover intent, audio changes, recovery, stale responses,
new-title resets, and unchanged versus explicit menu selections. Real-device
verification includes Rooibos and focused media-options/playback automation.
