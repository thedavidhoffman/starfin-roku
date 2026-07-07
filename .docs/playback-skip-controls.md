# Playback Skip Controls

This note documents the playback controls behavior for the visible skip-back
and skip-forward buttons in `PlaybackControls`.

## Button Rules

### Movies

- Skip back, shown as the left skip button, restarts the current title from the
  beginning.
- Skip forward, shown as the right skip button, is disabled and shown in a
  grayed-out state.

### TV Episodes

- Skip back with a previous episode available:
  - Within the first 15 seconds, starts the previous episode.
  - At 15 seconds or later, restarts the current episode.
- Skip back with no previous episode available restarts the current episode.
- Skip forward with a next episode available starts the next episode.
- Skip forward with no next episode available is disabled and shown in a
  grayed-out state.

## Focus And Disabled State

- Disabled skip buttons stay visible so the controls layout remains stable.
- Disabled skip buttons are skipped during button focus navigation.
- Disabled skip buttons should not emit playback actions.

## Implementation Notes

- Progress-bar left/right and remote rewind/fast-forward seeking remain separate
  from visible skip button behavior.
- TV previous/next uses the current playback queue and queue index.
- Moving to a previous or next episode should emit current playback progress
  before starting the new item.
- Restarting a movie or episode means seeking the current player to position
  `0` and staying in the player.
