# Next Item Playback

Starfin applies one per-user continuation preference whenever a completed video
has another valid item in its playback queue. The **Next Item Playback** setting
is available under **Current User > Playback**.

## Completion Modes

- **Show Up Next** is the default. Completion closes the player and opens the
  Up next screen with the completed and upcoming items. The next item starts
  when selected or when the 15-second countdown expires; Back cancels.
- **Play Next Immediately** starts the next queue item without showing Up next.

The preference applies to sequential, playlist, and random queues. If no valid
next item exists, playback closes normally. Completing an item through either
mode finalizes its progress and watched state before continuing.

## Media-Segment Actions

When Jellyfin reports an official `Outro` media segment and the queue has a
valid next item, the player displays a contextual action during the actionable
portion of the segment:

- **Skip Credits** completes the item and opens Up next when Show Up Next is
  selected.
- **Play Next** completes the item and immediately starts the next queue item
  when Play Next Immediately is selected.

Explicit completion reports the full item duration and waits for Jellyfin's
watched-state request to finish before advancing. This prevents the next
episode's playback lifecycle from overtaking the completed item's persistence.

Back dismisses the action for the current outro without completing playback.
The player does not infer credits from duration or recognize a non-standard
`Credits` segment type. Skip Intro and the random music-video Skip action retain
their existing priority and behavior.
