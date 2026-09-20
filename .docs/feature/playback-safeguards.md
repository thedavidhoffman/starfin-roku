# Playback Safeguards and Diagnostics

This note documents the low-risk playback correctness and diagnostic measures
used by `VideoPlayer`. They were added while investigating reports of playback
appearing to jump backward on Roku.

The investigation established that backward-looking playback can have more
than one cause. A Roku `Video.position` regression is observable by the app,
but repeated HLS media can be displayed while `Video.position` continues to
advance. The player therefore records suspicious activity but does not
automatically seek or restart solely because a position regression is seen.

## Playback Request Correlation

Each playback request receives an incrementing `requestId` before it is sent to
`VideoPlaybackInfoTask`. The task copies that ID into every success or error
response.

The ID is added by deriving a pending `PlaybackRequest` snapshot. A matching
successful `PlaybackResponse` is the only path that commits `ActivePlayback`;
failed and stale responses leave the currently active state unchanged.

`VideoPlayer` accepts a playback-info response only when its `requestId`
matches the current request. Older responses are ignored and logged:

```text
Ignoring stale playback info response responseRequestId=3 currentRequestId=4
```

This prevents a delayed task response from combining an old stream URL,
Jellyfin play session, or start position with newer playback state. This is
particularly important during playback recovery, playback-mode changes,
audio/subtitle changes, and rapid queue transitions.

The request ID is local to the active `VideoPlayer` instance. It is included in
the task request and response but is not sent to Jellyfin as an API field.

## Intentional Seek Tracking

Before assigning `Video.seek`, the player records the reason, current position,
target position, player state, item ID, and Jellyfin play-session ID. Tracked
actions include progress-bar seeks, skip backward/forward, restart, chapter
selection, Skip Intro, and seeking to the final five seconds.

An intentional seek produces a message similar to:

```text
Playback seek requested reason=skipPlayback:-10 from=842.1 to=832.1 delta=-10
```

A requested seek retains its reason and target for up to ten seconds after the
request. The first position within five seconds of the target establishes arrival;
a matching initial backward movement is classified as `expected`. After arrival,
a backward movement of more than two and at most five seconds is classified as
`seek-adjustment` only when both positions are within five seconds of that target.
The label indicates correlation with a recent seek, not proof of its cause.

The context expires after ten seconds, when playback leaves the target's
five-second neighborhood after arrival, or when replacement content is assigned.
A newer seek replaces it. Larger regressions and movements without qualifying
context remain `UNEXPECTED`. Content-assignment expectations keep their existing
single-arrival behavior. These diagnostics do not change seek commands, recovery,
completion decisions, or reported playback progress.

## Backward-Position Diagnostics

The player tracks the last observed Roku `Video.position`. A movement more than
two seconds backward is logged as `expected`, `seek-adjustment`, or `UNEXPECTED`:

```text
Playback position moved backward classification=UNEXPECTED from=842.1 to=812.0 delta=-30.1
```

The diagnostic includes the prior and new positions, delta, expected seek,
player state, buffer percentage, item ID, and play-session ID. Logging does not
alter the position, issue a corrective seek, or change playback mode.

## Session Diagnostics

The player logs lifecycle information without exposing tokens or complete
stream URLs:

- Playback request, item, mode, requested start, and current position.
- Content assignment, play-session ID, stream format, and start position.
- Video state transitions and buffering percentage.
- App-directed seeks and their reasons.
- Expected and unexpected backward-position changes.
- Jellyfin playstate start, update, and stop positions.

Capture the Roku debug console on port `8085` before playback and retain the
corresponding Jellyfin server and FFmpeg logs. Useful search terms are:

```text
Playback request
Playback content assignment
Playback state transition
Playback seek requested
Playback position moved backward
Ignoring stale playback info response
```

## Validation Scenarios

1. Play normally and confirm forward updates do not produce regression logs.
2. Exercise each seek control and confirm backward movement is `expected`.
3. Change playback mode, audio, and subtitles and confirm the newest request ID
   is used for the resulting content assignment.
4. Rapidly replace a playback request and confirm any older task response is
   ignored.
5. Confirm Jellyfin start, progress, and stop reports use the active session.

Project validation should continue to pass with:

```text
npm run validate
```

## Premature Completion

Before accepting Roku `finished`, VideoPlayer compares the accepted item's
metadata runtime with recovery's last position observed while playing or paused.
It allows 2 percent of runtime at the end, clamped to a minimum of one second
(two default Roku position-notification intervals) and a maximum of 30 seconds. Missing
metadata runtime retains the existing completion behavior; the stream duration
is not authoritative because a truncated stream may report a shortened duration.

An earlier finish reports a normal stop at the saved position, emits unfinished
progress, and enters the existing recovery retry/fallback path. It does not mark
the item watched, advance the queue, or open Up Next. If retries are exhausted,
the player reports failure with resume progress preserved.

The playback state freezes that position until replacement content is accepted,
so terminal position jumps, zero resets, duplicate finished notifications, and
shutdown cannot overwrite it. Accepted content releases the freeze and seeds
the recovery position from its start position. Subsequent observed seeks update
the recovery position normally, including backward seeks. Explicit user actions
to complete an item retain their existing behavior.

All app-directed seeks use `requestPlaybackSeek`, which records the latest
committed target separately from diagnostics before assigning `Video.seek`.
A seek to the metadata endpoint allows completion without another position
notification. A newer seek replaces that intent, and an observed playing/paused
position or replacement content clears it. Merely seeking to the end of a
truncated stream does not count as reaching the metadata endpoint.

Playback session phase owns Video event handling for every request: `stopped`,
`resolving`, or `active`. Stopping disables state, position, duration, and queued
recovery timer effects before issuing `Video.control = stop`. Starting a request
enters `resolving`; only its matching response can accept content and enter
`active`. Recovery, media-option changes, and queue transitions all use this
same path. The former recovery-only restart flag is removed.

Outgoing events cannot complete an item, change duration/progress, report a new
start, reset retries, or cancel replacement work. Playback-info failures remain
actionable during resolution. Cancellation enters `stopped`, where late responses
and terminal events cannot restart playback. Accepted replacement content can
still fail before reaching `playing`, and its failures enter normal recovery.

If playback finishes while a backward seek remains unresolved, completion uses
the earlier requested position instead of the old near-end observation. Unfinished
progress and recovery both use that position, including a restart at zero. A newer
seek replaces the intent, and an observed playing/paused position takes precedence.
Forward seeks below the metadata endpoint retain the last observed recovery
position; the existing explicit endpoint exception remains.

The diagnostic `Playback ended prematurely position=... runtime=...` records the
decision; recovery logs use reason `prematureFinish`. This protects completion
handling but does not establish or repair the underlying stream failure.

Component regression coverage lives in `VideoPlayer.spec.bs` and covers early
termination, shortened stream duration, terminal position jumps, repeated events,
retry exhaustion, completion boundaries, short-clip sampling, missing runtime,
endpoint seek event orderings, outgoing recovery notifications, replacement
startup failures, cancellation, and replacement content initialization.

## Known Limitation: Repeated HLS Media

Roku can display earlier HLS media while continuing to report an increasing
`Video.position`. Position-regression detection cannot identify or safely
correct that condition.

In the investigated Jellyfin remux case, FFmpeg copied HEVC video into MPEG-TS
HLS with a six-second target and `BreakOnNonKeyFrames=False`. Actual segment
cuts followed more widely spaced source keyframes. Later FFmpeg jobs restarted
the same HLS cache using nominal segment-number timing and supplied earlier
media during the credits. The Roku clock continued forward throughout.

That server-side segment-timeline behavior must be addressed through playback
profile/segmentation changes or a no-remux playback mode. It must not trigger
an automatic client recovery based only on `Video.position`.
