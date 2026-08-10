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

The expected target remains active until Roku reports a position within five
seconds of it. A matching backward movement is classified as `expected`.

## Backward-Position Diagnostics

The player tracks the last observed Roku `Video.position`. A movement more than
two seconds backward is logged and classified as either expected or unexpected:

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
