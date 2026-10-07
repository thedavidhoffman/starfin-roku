# Playback Workflow and State Ownership

Multi-version movies carry a source catalog separately from negotiated playback
data. Source selection, metadata, resume, and recovery are described in
[Movie Versions](movie-versions.md).

Video playback uses three explicit assocarray value contracts. These contracts
cover every media type routed through `VideoPlayer`; music audio and theme audio
use separate workflows.

## Pure playback helpers

The six component-specific pure playback helpers live in
`source/video-player-helpers`: playback control calculations,
playback-information formatting, media segments, metadata,
stream selection, and trickplay calculations. Each exposes a responsibility-named
namespace, such as `VideoPlayerMetadata.GetRuntimeSeconds`; internal members use
the `__` prefix. Their calculations and state ownership are unchanged.

Pure means independent of component `m` state; it does not imply use by multiple
components. These helpers retain their component-specific playback responsibilities.

Their source paths match the existing package import paths. Production, Rooibos,
and automation builds include them once through `source/**/*`, with no helper
remapping or exclusion rules. The six existing pure test suites mirror that
location under `tests/rooibos/specs/source/video-player-helpers`; component suites
continue to cover rendering, focus, events, and playback integration.

## Estimated finish time

PlaybackControls shows `Ends at 1:50 PM` above the timeline's right edge.
It estimates the current title's completion from the current local clock plus
remaining duration, using the same 12-hour AM/PM format as the playback clock.
The estimate follows the seek preview and returns to actual position on cancel.
Unknown or nonpositive durations hide the label; positions are clamped to the
known duration. It does not predict the completion of the entire queue.

A component-owned one-second timer runs only while controls are active, visible,
and have a known duration. Pausing and buffering therefore advance the estimate
without requiring position events. Hiding or deactivating controls stops the
timer; opening them recalculates immediately. Progress and seek changes also
refresh immediately, but unchanged label text is not reassigned. Existing
DateTime helpers own timestamp conversion and local time formatting.

The label is non-focusable and does not alter timeline or button navigation.
No server requests, registry settings, or localization migration are introduced.

## Instant Replay

VideoPlayer handles the remote `replay` press with the existing
`skipPlayback(-10)` path. The target is clamped to zero; playing/paused state is
preserved, progress and preview fields update together, and the normal controls
presentation and hide timer are used. Subtitle selection and the accepted
playback request remain unchanged.

The same `requestPlaybackSeek` path records the destination for recovery and seek
diagnostics. Replay does not restart playback or change its return destination.
Only active, seekable, playing/paused video accepts the seek; seek preview, cast
browsing, startup/recovery, buffering, and stopped playback ignore it. The interval
is fixed at ten seconds with no registry preference.

## Workflow at a Glance

Selecting an item moves snapshots between owners; it does not turn the library
page's item or queue into player-owned state.

```text
Library page
    |
    | selected item + queue context
    v
MainScene
    |
    | playRequest command
    v
PlaybackController
    |
    | owned player lifecycle
    v
VideoPlayer
    |
    | owned PlaybackRequest snapshot
    v
VideoPlaybackInfoTask
    |
    | correlated PlaybackResponse
    v
VideoPlayer
    |
    | matching success commits ActivePlayback
    v
Roku Video node
```

The page and player may retain references to large, read-only metadata, while
the mutable boundaries needed by playback are owned separately:

```text
Library/detail state                 VideoPlayer state

item ---------------- read-only ---- item metadata
  `-- UserData (page-owned)            `-- UserData (player-owned copy)

queue array (page-owned)             queue array (player-owned copy)
  `-- read-only entries ---- shared ----^ except current entry wrapper
```

## PlaybackRequest

`PlaybackRequest` is a command snapshot describing the item, session context,
resume position, selected streams and mode, and queue context for one playback
attempt. `MainScene` submits the initial command and `VideoPlayer` creates its
owned snapshot. Queue transitions, stream changes, video-mode changes, and
recovery retries derive new snapshots with `PlaybackRequest.WithChanges()`
rather than modifying the submitted request. Snapshot creation copies the
mutable current-item progress and queue container while treating large nested
media and navigation metadata as read-only.

`PlaybackController` is the app-shell boundary for the active `VideoPlayer` node.
It creates and wires the player, forwards narrow player events, delegates shell
commands such as focus and overlay completion, captures the restoration snapshot,
and removes the player after close. It does not own `ActivePlayback`, Roku runtime
state, playback tasks, page visibility, focus-restoration decisions, or navigation.

`VideoPlayer` assigns a local incrementing `requestId` by deriving another
snapshot with `PlaybackRequest.WithRequestId()`. The correlated snapshot becomes
the player's pending request and is sent to `VideoPlaybackInfoTask`.

## PlaybackResponse

`VideoPlaybackInfoTask` resolves one `PlaybackRequest` into a
`PlaybackResponse`. Success and failure responses always include the originating
`requestId`, `ok`, and `action`. Success adds the resolved stream, Jellyfin play
session, resolved stream fields, start position, and subtitle data. Failure
adds the available error details.

When a selected subtitle is burned into a resolved transcode, the response
reports `subtitleDeliveryMethod` as `encode` and omits the selected
`externalSubtitleTrack`. The list of available external tracks remains present
for later stream selection, but Roku does not attach a second copy of the
currently encoded subtitle.

The task does not own playback state. `VideoPlayer` ignores any response whose
ID does not match its pending request.

```text
pending request #12 ------------------------------+
                                                    |
response #11 (late) --> ID mismatch --> discard     |
                                                    |
response #12 ----------> ID match + success --------+
                                      |
                                      v
                              commit ActivePlayback
                                      |
                                      v
                              assign Video.content
```

A matching failure reports the failed attempt but does not replace an already
accepted `ActivePlayback`.

## ActivePlayback

Only a successful current response can establish `ActivePlayback`. `VideoPlayer`
commits it atomically before assigning content to the Roku `Video` node. It is
the canonical owner of:

- the accepted request and correlation ID;
- Jellyfin session and resolved stream, codec, and selection fields;
- current item, series, and season context;
- queue items, index, mode, and scope.

The player's helper scripts share the owning component context and may update
queue state through the existing queue workflow. Components outside
`VideoPlayer` do not read or mutate `ActivePlayback`.

Roku runtime mechanics such as position, duration, seeking, startup flags, and
playstate flags remain in the separate `m.playback` state object.

```text
PlaybackRequest     what this attempt asks for
       |
       v
PlaybackResponse    what the server resolved for that attempt
       |
       v
ActivePlayback      what VideoPlayer accepted as canonical playback state

m.playback          Roku runtime mechanics for that accepted playback
```

Movie Resume requests preserve an absent `startPositionTicks` through routing,
so playback resolution uses the selected version's UserData after metadata
loading. Explicit positions, including Restart zero and chapter/player restart
positions, remain authoritative. Movie's `applyPlaybackSelection` restoration
interface accepts the version context together with audio and subtitle state.

## Close Restoration

The `playRequest` SceneGraph field is input-only. When playback closes,
`PlaybackController` captures `getRestorePlaybackRequest()` through the player
interface and publishes the snapshot in its `closed` event to MainScene.
The function returns a copy of the accepted active request, including current
queue reconciliation. If startup never succeeded, it returns the pending
request so navigation can still restore the originating surface.

Progress crosses the ownership boundary as an explicit event rather than by
mutating a shared item:

```text
VideoPlayer owned item.UserData
              |
              | playbackProgressChanged payload
              v
MainScene routing
              |
              v
Library/detail page updates its own item.UserData

VideoPlayer -- getRestorePlaybackRequest() --> MainScene navigation restore
```

## Shared playback return context

MainScene owns one grouped playback return state for ordinary video, remote Play,
and album playback. Launch callers supply their origin before it is hidden or
deactivated. The context records the page, header visibility, and a
`PlaybackReturn.Behavior`: Page, Movie, Episode, or Playlist. A launch identity
changes for an explicit new title, while next-episode continuation preserves it.
Navigation state remains separate from the accepted playback snapshot.

Player closure and next-episode prompt cancellation use the same restoration
path. Movie restores accepted version/audio/subtitle choices. Episode detail
playback reconciles the final queued episode, restores subtitle intent, and
refreshes playback data. Playlists focus the latest queue item's index. Browsing
pages use their existing activation/focus behavior; Home retains its existing
refresh and focus handling. Before applying metadata or activating a retained
page, restoration rebinds MainScene's corresponding page reference. This keeps
page events routed to the displayed Movie or TVShow after Person navigation
replaces and closes another detail page. Removed destinations fall back to Home.
Restoration consumes the context, and dynamic-page/session teardown clears it.

Person is a temporary detour from playback. It saves the launch identity, return
context, and accepted snapshot through PlaybackController's
`getRestorePlaybackRequest` interface. Closing Person resumes the suspended player
only if its launch identity still matches. An explicit title launch from Person
replaces the playback destination with Person; closing Person after that player
has closed restores the saved original destination. An existing return context
does not block another title launch. Remote input still requires a visible,
focused origin and rejects blocking overlays/loading; hiding the origin prevents
repeat launches.

Deep links resolve their existing retained-page return precedence at launch.
Cold movie playback returns Home; cold episode playback retains episode-detail
reconciliation. Pending deep-link cancellation and failures continue through the
existing fallback lifecycle. Ordinary playback failures remain on the stopped
player until Back. Album completion also continues leaving AudioPlayer displayed.
PlaybackController rejects notifications from replaced video players; MainScene
matches audio-close notifications to its current AudioPlayer. Explicit replacement
launches deactivate and detach the previous audio player before opening new media.

## Remote Play from browsing

Pages emit `playbackSelected` for the focused playable item. MainScene routes the
selection to the existing player. Direct episode playback returns to the browsing
page without creating an episode detail page. Playback errors retain the existing
recovery and acknowledgment behavior; Back returns to the originating page.

Direct video requests set `loadItemDetails`. VideoPlaybackInfoTask loads complete
metadata, including `People` for the player's Cast option, with explicit session
context before negotiation, rejecting missing, changed, or unavailable items.
Videos resume from their loaded UserData; movies
use the first source and its version-specific resume data. Detail-page playback
retains the selected version and stream choices. Accepted metadata stays with the
playback request and the loading flag is cleared for recovery and stream changes.
Available season and playlist queue context is retained; other direct launches
play only the highlighted video without discovering a new queue. Home videos
bypass the choice dialog when launched by remote Play.
