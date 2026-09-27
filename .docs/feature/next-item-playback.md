# Next Item Playback

Starfin applies one per-user continuation preference whenever a completed video
has another valid item in its playback queue. The **Next Item Playback** setting
is available under **Current User > Playback**.

## Completion Modes

- **Show "Up Next"** is the default. Completion closes the player and opens the
  Up next screen with the completed and upcoming items. The next item starts
  when selected or when the 15-second countdown expires; Back cancels.
- **Play next immediately** starts the next queue item without showing Up next.

The preference applies to sequential, playlist, and random queues. If no valid
next item exists, playback closes normally. Completing an item through either
mode finalizes its progress and watched state before continuing.

## Media-Segment Actions

When Jellyfin reports an official `Outro` media segment and the queue has a
valid next item, the player displays a contextual action during the actionable
portion of the segment:

- **Skip Credits** completes the item and opens Up next when Show "Up Next" is
  selected.
- **Play Next** completes the item and immediately starts the next queue item
  when Play next immediately is selected.

Explicit completion reports the full item duration and waits for Jellyfin's
watched-state request to finish before advancing. This prevents the next
episode's playback lifecycle from overtaking the completed item's persistence.

Back dismisses the action for the current outro without completing playback.
The player does not recognize a non-standard `Credits` segment type.
Duration-based episode fallback is opt-in as described below. Skip Intro and
the random music-video Skip action retain their existing priority and behavior.

## Series Artwork

Episode queue expansion supplies lightweight series identities. When the next
episode belongs to the same series, playback retains already-loaded series
metadata instead of replacing it with only an ID and name. Both the Up Next
request and direct episode advancement use this selection, preserving the show
logo after playback launched from Home. Incoming loaded metadata (including
confirmed missing artwork) and explicit playlist contexts remain authoritative;
artwork is never borrowed from a different series.

## Credits fallback

Current user > Credits contains **Show next episode prompt**, an account-scoped
setting with Off (default), 15 seconds, 30 seconds, 45 seconds, 60 seconds,
75 seconds, 90 seconds, 105 seconds, and 120 seconds.
The registry key
`next-episode-prompt-seconds` stores the selected seconds as a string; missing or
unsupported values become `"0"` (Off). Changes use the normal settings save flow.

For episodes with a valid next queue item, a known duration, and no usable
Outro range, the selected interval supplies a derived outro from duration minus
the interval to the end. The duration must exceed the interval. Movies and
other media do not receive this fallback. Official outros always take precedence,
even outside their actionable range. Fallback waits until playback information
reports no segments or segment loading succeeds without a usable outro. Pending
or failed segment requests do not enable it; stale item responses are ignored.

The derived range uses the existing action path: Show Up Next displays
**Skip Credits**, and immediate continuation displays **Play Next**. The action
appears at the selected threshold and hides during the final five seconds,
matching official outros. Intro actions retain priority. Back dismisses the
fallback by episode identity, including after seeking away and back or a
reported-duration correction; the next item resets dismissal. Official segment
dismissal remains separate and uses the segment end time. Pressing the action uses the existing watched-state completion
flow. Display alone never skips or marks an episode watched.

The explicit playback request field `nextEpisodePromptSeconds` preserves this
preference through direct queue transitions, Up Next, and playback restarts.

`SettingsStore.GetSettingValue` normalizes next-item playback, next-episode prompt
seconds, and subtitle burn-in preferences. Playback request construction uses those
values directly; selection overrides are normalized separately because they do not
come through the settings store.

MediaSegments owns availability through `resolved`: false while availability is
unresolved or a request has failed, true after either a no-segments result or a
successful segment response. Both results use one resolution path to build ranges
and refresh the action. Official and fallback evaluation have separate local
helpers and dismissal rules; the dispatcher always chooses official ranges first.

## Prompt diagnostics

VideoPlayer logs `Playback action displayed` when Skip Intro, Skip Credits, or
Play Next appears or changes action/source. Each entry includes the action mode,
item ID, playback position, timing source (`intro-segment`, `outro-segment`, or
`next-episode-setting`), and range end. Setting-based entries also include
`settingSeconds`. An unchanged visible prompt does not generate another entry.

Selecting Skip Credits or Play Next logs `Playback action clicked` with the same
context before dismissal and completion. Repeated selections while completion is
pending are ignored. Back dismissal does not produce a click entry. Intro selection
retains the existing `Skipping intro` entry with item, position, and seek target,
plus its activity-log entry.

Segment requests carry a monotonically increasing request ID. The player accepts
only the outstanding request for the current item; stopping, resetting, or replacing
a load invalidates it. Recovery cancellation preserves resolved ranges and dismissal
state. Success and failure consume the pending request, so duplicate responses are
ignored. Active outro results contain copied range values and source metadata;
evaluating an official outro does not modify the stored range.

Playback action presentation requires an active playback session and no pending
completion. Stopped or resolving sessions cannot display prompts even while the
Video node still reports playing during an asynchronous state transition.
