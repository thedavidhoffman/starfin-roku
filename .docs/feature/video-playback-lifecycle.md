# Video Playback Lifecycle

## Back Navigation

Pressing Back while the playback controls and other dismissible playback UI are
hidden exits video playback immediately. The player publishes final progress,
starts the Jellyfin playback-stop report, stops the local Roku `Video` node, and
requests navigation back to the originating detail page without waiting for the
HTTP response.

The stop response has no UI or navigation side effects. This prevents server
response time, including the extra time Jellyfin may need to terminate an HLS
transcode, from delaying the local player close.

## Rapid Replay

A user may start playback again from the detail page while the prior stop report
is still completing. The new `VideoPlayer` component owns a separate
`PlaystateTask` and receives a new Jellyfin `PlaySessionId`; reports from the old
player retain the old session identity. New playback therefore starts
immediately and does not wait for the prior stop response.

Late stop responses are intentionally ignored. They cannot close, stop, or
otherwise mutate the replacement player.

## Player Replacement

If a new playback command arrives while a player is still owned, the existing
player publishes final progress and starts its Jellyfin stopped report before
`PlaybackController` removes it. This shutdown does not emit `closeRequested`,
so replacing suspended playback does not restore the old navigation surface.
The new player can start immediately while the prior stopped report completes.

## Playback Close State

The `playRequest` field is an input command rather than shared active state.
When `VideoPlayer` closes, `PlaybackController` requests a restoration snapshot
through `getRestorePlaybackRequest()`. The accepted `ActivePlayback` request is
preferred; the pending request is used only when playback never became active.

The player close event is received by `PlaybackController`, which captures the
restoration snapshot and any pending up-next request before removing the player.
It publishes those values as one close payload. `MainScene` consumes that payload
and decides which page to restore; the controller has no page or navigation
knowledge.

## Shell Delegation

`MainScene` sends player-specific shell actions through `PlaybackController`,
including focus recovery, playback-info and stream-options overlay completion,
and temporary pause/hide/resume behavior for person navigation. These commands
delegate to the active player when one exists and otherwise have no effect.
