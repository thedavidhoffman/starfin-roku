# Playback Workflow and State Ownership

Video playback uses three explicit assocarray value contracts. These contracts
cover every media type routed through `VideoPlayer`; music audio and theme audio
use separate workflows.

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

## Close Restoration

The `playRequest` SceneGraph field is input-only. When playback closes,
`MainScene` calls `getRestorePlaybackRequest()` through the component interface.
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
